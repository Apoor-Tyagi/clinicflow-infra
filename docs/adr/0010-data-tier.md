# ADR 0010: Data tier on RDS PostgreSQL

- Status: Accepted
- Date: 2026-11-15
- Related: ADR 0006 (CI and image publishing), infra PR #18 (RDS module), infra PR #17 (DynamoDB audit table)

## Context

ClinicFlow stores patient and booking data in PostgreSQL. Tenant separation is enforced in the database with row-level security (RLS), proven by six isolation tests in `tests/test_tenant_isolation.py` that run in CI against a real Postgres container.

The data tier must run in AWS, stay cheap while the project is in learning mode, and keep database credentials out of code, images and Terraform state wherever possible.

## Decision

Use Amazon RDS for PostgreSQL, provisioned by the `data-rds` Terraform module, with the master password managed by RDS in AWS Secrets Manager (`manage_master_user_password = true`).

Dev configuration (`envs/dev/main.tf`):

| Setting | Value |
|---|---|
| Engine | PostgreSQL 17.11 (`postgres17` parameter group) |
| Instance class | `db.t4g.micro` |
| Storage | 20 GiB gp3 |
| Multi-AZ | off |
| Backup retention | 1 day |
| Deletion protection | off |
| Encryption | project KMS key (storage and master secret) |
| Network | data subnets; ingress only from the k3s node security group |

### Why RDS with a managed master secret

- RDS creates the master password, stores it in Secrets Manager and rotates it. No password appears in Terraform code, variables or CI logs.
- The node reads the secret at bootstrap through a narrowly scoped IAM permission instead of receiving a password from a file or environment variable.
- Running Postgres ourselves on the k3s node would save money but makes us responsible for backups, patching and storage failure, which is the wrong trade for patient data.

## Cost

These are estimates for us-east-1 on-demand pricing. Verify against the AWS pricing pages before relying on them, since prices change.

| Item | Basis | Estimate |
|---|---|---|
| Instance | `db.t4g.micro`, single-AZ PostgreSQL, about $0.016 per hour | about $12 per month if left running |
| Storage | 20 GiB gp3, about $0.115 per GiB-month | about $2.30 per month |
| Backups | 1 day retention, within the free backup allowance for the database size | about $0 |
| Master secret | $0.40 per secret per month, plus a small per-API-call charge | about $0.40 per month |
| KMS key | $1 per month, shared with the rest of the project | already paid, not new |

Running total: about $0.019 per hour, or roughly **$15 per month** if left up continuously. Learning sessions are a few hours each, so the real cost is cents per session, provided the stack is destroyed afterwards. A forgotten stack costs the full monthly amount.

## Trade-offs accepted for dev

Each of these has a written `#checkov:skip` reason in `modules/data-rds/main.tf`.

- **No Multi-AZ (CKV_AWS_157).** A standby doubles the instance cost. An AZ failure means downtime. Production would enable it.
- **No enhanced monitoring (CKV_AWS_118) and no Performance Insights (CKV_AWS_353).** Both need extra setup and, at scale, extra cost. Production would enable them.
- **Deletion protection off (CKV_AWS_293).** So dev can be destroyed after each session. The module sets `skip_final_snapshot = !var.deletion_protection`, so with protection off, `terraform destroy` takes **no final snapshot and the data is permanently lost**. This is acceptable only because dev holds no real patient data. Never use this configuration with real data: production sets `deletion_protection = true`, which also turns on the final snapshot.
- **1 day of backups.** Enough to recover from a mistake during a session, not a retention policy. Production needs a longer window that meets its record-keeping obligations.

## Row-level security on RDS

The RLS design is plain PostgreSQL, so it runs the same on RDS as on the CI container:

- Tenant tables have RLS enabled, with policies that compare each row's clinic to a per-request session setting.
- Migrations run as the admin user (`clinicflow_admin`). The API connects as a separate **app role** that does not own the tables and does not have `BYPASSRLS`.
- With no clinic selected, the app role sees nothing.

RDS caveat: the master user is a member of `rds_superuser`, which is **not** a true superuser. It can create roles and run migrations, but some superuser-only operations are unavailable. The API must never connect as the master user, because an owner or privileged role can sidestep RLS. The app role is created by the bootstrap script after the migration.

The check that this holds on RDS is `test_app_role_cannot_bypass_row_level_security`. It must be run against the RDS instance during the first data-tier session, not only in CI.

## Consequences

- **TLS is required.** RDS is configured to force TLS, so `DATABASE_URL` must include `sslmode=require`. A URL without it fails to connect.
- **Bootstrap flow.** The bootstrap script fetches the master secret, runs the migration as `clinicflow_admin`, creates the app role, and builds `DATABASE_URL` for the API with the app role's credentials.
- **Node IAM.** The instance role gets `secretsmanager:GetSecretValue` on the single master secret plus KMS decrypt for it, and `dynamodb:PutItem` and `dynamodb:Query` on the audit table plus KMS access for DynamoDB. No wildcard resources.
- **Operating model.** The data tier is applied only in deliberate sessions, after a price check, and destroyed at the end. A session script owns that flow.
- **Production gap.** Multi-AZ, monitoring, longer backups, deletion protection and a final snapshot are all required before any real patient data is stored.
