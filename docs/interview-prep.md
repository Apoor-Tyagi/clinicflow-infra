# ClinicFlow interview prep

Last updated 2026-11-23.

Everything you need to explain ClinicFlow in an interview: the pitch, the architecture, the tools, the problems solved, and answers to the questions most likely to come up.

## The project in 60 seconds

ClinicFlow is a multi-tenant clinic appointment and reminder platform that I built to show cloud engineering end to end. A clinic's front desk books appointments in a web UI, and patients get an email reminder 24 hours before. The application is deliberately small; the platform around it is the point.

I built it on AWS with Terraform, ran it on a single k3s node deployed by Argo CD, and kept each clinic's data separate with PostgreSQL row-level security. Reminders run through EventBridge Scheduler, SQS with a dead-letter queue, and a worker that sends through SES and records an audit entry in DynamoDB.

Then I tested it for real on AWS and wrote down what broke. The fixes and measurements are in the project's decision records, and the environment was destroyed after each session to control cost.

- **Say this first:** infrastructure as code, CI/CD, GitOps, security, observability, cost control and disaster recovery, all measured on real AWS.
- **Three repositories:** `clinicflow-infra` (Terraform), `clinicflow-app` (API, UI, dispatcher, worker, CI), `clinicflow-gitops` (Kubernetes manifests, Argo CD, monitoring).

## How it works

A booking becomes an email in seven steps. Be ready to walk through them in order.

1. **Book.** The front desk UI calls the FastAPI service. Each clinic signs in with its own API key; only a SHA-256 hash of the key is stored.
2. **Isolate.** Every query runs in a transaction that sets `app.clinic_id`, and PostgreSQL row-level security (forced, with a role that cannot bypass it) shows each clinic only its own rows.
3. **Queue the reminder.** Booking writes the appointment and a row in a `reminders` table in the same transaction. This is a transactional outbox, so a reminder is never lost or created without its appointment.
4. **Schedule.** A dispatcher on the node reads pending rows and creates a one-time EventBridge Scheduler schedule named `reminder-<appointment id>`. The fire time is the later of the reminder time and one minute from now.
5. **Deliver to a queue.** At the fire time, Scheduler puts a message on an SQS queue encrypted with a customer-managed KMS key.
6. **Send.** The worker reads the message, checks DynamoDB for an existing audit record (strongly consistent), sends the email through SES, and then writes the audit record. Failures retry; after three receives the message moves to a dead-letter queue.
7. **Alert.** A CloudWatch alarm on the dead-letter queue notifies an SNS topic that emails me.

Why the API has no AWS credentials: the dispatcher and worker run as hardened systemd services on the host using the node's IAM role. The API pod cannot reach the instance role, because IMDSv2 is required with a hop limit of 1. If someone breaks into the API, they cannot call AWS from it.

## Tools used and why

| Area | Tool | Why I chose it |
| --- | --- | --- |
| Infrastructure as code | Terraform, S3 remote state with lockfile | Repeatable builds and teardowns; state in S3 so it is shared and locked |
| Compute | EC2 t3.medium running k3s | One node instead of EKS, because a managed control plane bills while idle |
| Database | RDS PostgreSQL | Row-level security gives per-clinic isolation inside one database |
| Containers | Docker multi-stage build, non-root user, ECR | Small runtime image with pip removed; multi-architecture images |
| GitOps | Argo CD, Kustomize | The cluster state lives in Git and is synced, not applied by hand |
| CI/CD | GitHub Actions with OIDC | No stored AWS keys; short-lived roles per repository |
| Scanning and linting | Trivy, Checkov, tflint, pre-commit, Dependabot | Fail builds on fixable high findings; catch policy and style problems early |
| Scheduling | EventBridge Scheduler (one-time `at()`) | Per-appointment reminders without running a cron loop |
| Messaging | SQS, dead-letter queue, KMS customer-managed key | At-least-once delivery, retries, and a place for poison messages |
| Email | SES v2 (sandbox mode) | Cheap sending; sandbox requires verified recipients |
| Audit | DynamoDB | One audit record per reminder, used to drop duplicates |
| Observability | Prometheus metrics, Grafana, CloudWatch alarm, SNS | SLO alerts under fault injection; DLQ alert by email |
| Access | SSM Session Manager (no SSH, no key pair) | Nothing is exposed publicly; access is logged under IAM |
| Resilience | AWS Backup with cross-region copy (us-west-2) | Tested restore into another region |
| Audit trail | CloudTrail with log validation | Evidence of API activity; digests verified |
| Cost control | AWS Budgets, destroy after each session, 4-hour node auto-shutdown | Keeps the bill in cents |
| Application | Python, FastAPI, psycopg, boto3, pytest | Small API, worker and dispatcher; 49 tests |
| Documentation | Architecture decision records (ADRs), threat model, runbooks | Each decision has its reason written down |

## What I built in each repository

**clinicflow-infra (Terraform)**

- A bootstrap configuration with local state: the state bucket, GitHub OIDC provider and roles, the ECR repository, CloudTrail and a budget.
- Modules for the network (no NAT gateway), the k3s node, the data tier (RDS, DynamoDB), messaging (SQS, KMS, SES, alarm), backups and security roles.
- A dev environment, a DR environment in us-west-2, pull-request CI (fmt, validate, tflint, Checkov, read-only plan), decision records (ADRs), a threat model and a disaster recovery runbook.

**clinicflow-app (application and CI)**

- A FastAPI service with tenant-scoped clinic, patient and appointment APIs, plus a front desk web UI (served with a strict content security policy).
- SQL migrations with row-level security, a per-clinic API key scheme, and two database roles that cannot bypass security (`clinicflow_app` and `clinicflow_dispatcher`).
- The dispatcher and the reminder worker, a hardened Docker image, and a CI pipeline: tests, Trivy scan, and a multi-architecture image pushed to ECR from `main` only.
- 49 automated tests, including tenant-isolation tests against a real PostgreSQL.

**clinicflow-gitops (Kubernetes)**

- Manifests and Kustomize overlays for the API, an Argo CD application definition, and the monitoring stack.
- The image tag is pinned to a commit SHA, so a deploy is a Git change.

## Problems I hit and how I solved them

Use these as stories: what I saw, the cause I proved, the fix, and what I took from it. Each was found by testing, not by reading docs.

| Problem | Cause | Fix | Lesson |
| --- | --- | --- | --- |
| The dead-letter alarm fired but no email arrived | An SNS email subscription stays `PendingConfirmation` and silently drops messages until confirmed | Resent the confirmation, clicked the newest link, forced the alarm again | An alert path is proven only when a human receives an alert |
| CloudWatch could not publish to the encrypted topic | The AWS-managed key cannot be used by CloudWatch | Customer-managed key with an explicit CloudWatch statement | Check who the service principal is, not only your own roles |
| One reminder sent two emails | The worker sent first and recorded afterwards, so a redelivery in between duplicated | Look up the audit record with a strongly consistent query before sending; conditional write as a second defence | SQS is at-least-once; make the consumer idempotent and document the case you cannot close |
| Terraform plan always showed a change | `rds.force_ssl` is a static parameter, but Terraform applied it as `immediate` | `apply_method = "pending-reboot"` | A plan that is never clean teaches you to ignore plans |
| The deployed image expired | ECR retention counts entries, and a multi-architecture push makes three | Raised the limit from 20 to 60 | Know what a policy actually counts |
| Apply failed halfway on SES | The sender identity had been created by hand earlier | `terraform import` | Bring manual resources under management |
| The new node booted but nothing ran | The boot script downloaded files from a pull request that was not merged yet; `curl -sf` with `set -euo pipefail` failed quietly on the 404 | Merged the pull request, replaced the node, and read the script output through cloud-init | Boot scripts need visible failures; diagnose with evidence, not guesses |
| The first real booking never produced an email | SES in sandbox mode checks `ses:SendEmail` against the recipient identity too, and my policy named only the sender | Allowed identities in the account, kept the From-address condition | Test with a recipient that is not the sender; log error codes, not just error types |
| A fresh clone could not log in locally | An exported `ADMIN_TOKEN` in my shell overrode `.env` in Docker Compose, and the compose file used a superuser that bypasses row security | Compose now applies the migrations and runs the API as the restricted role; README documents the override | Test the new-user path from a clean clone |
| A commit was blocked | My own pre-commit hook rejects any file ending in `.tfvars.example` | Renamed the example files rather than weakening the hook | Do not loosen a guardrail to fit one file |

## Design decisions and trade-offs

Interviewers like to ask "why not X?". These are the choices I made on purpose, with what each one costs.

| Decision | Why | Trade-off |
| --- | --- | --- |
| One k3s node on EC2, not EKS | A managed control plane bills while idle; this keeps the cost in cents | Single point of failure; a node failure means a rebuild or restore, not a failover |
| No NAT gateway, no SSH | Fewer billable parts and no exposed login; access through Session Manager | Slightly harder to debug; I used SSM `send-command` to run diagnostics |
| Row-level security in one shared database | Isolation is enforced by the database, so a missing `WHERE` clause cannot leak data | The master user bypasses it, so the guarantee covers only the application role |
| Transactional outbox plus a dispatcher | The API needs no AWS credentials, and a reminder cannot exist without its appointment | An extra moving part, and up to 15 seconds of polling delay |
| Worker and dispatcher as systemd services on the host | They use the node role, and the API pod cannot reach AWS | Not per-pod identity; a compromised worker holds the node's permissions |
| One-time EventBridge schedules with deterministic names | A repeated create is harmless, because a conflict means it already exists | One schedule per appointment, and the schedule holds the patient's email until it fires |
| At-least-once delivery with an idempotency check | Exactly-once is not available from SQS | A crash between send and record can still duplicate; documented |
| GitOps with Argo CD | Git is the source of truth and rollbacks are reverts | Needs a separate repository and an image-tag step |
| GitHub OIDC instead of stored keys | No long-lived credentials to leak | Role trust must be scoped carefully to the right repository |
| Destroy after every session | Keeps the account cost near zero | Each session starts from a rebuild, so the build path must stay reliable |

## Security, reliability and cost

**Security**

- **Tenant isolation:** forced row-level security, with an application role that is not a superuser and cannot bypass it. Tenant-isolation tests run against a real PostgreSQL in CI.
- **No stored cloud credentials:** GitHub Actions assumes roles through OIDC, and the node uses its instance role. The API pod cannot reach that role (IMDSv2, hop limit 1). I measured this: a pod timed out requesting a token (curl exit 28) while the node got HTTP 200.
- **Least privilege:** the dispatcher has its own database role with column grants and read-only policies; the worker's IAM policy names the specific queue, sender and table.
- **No public surface except what is needed:** no SSH, no key pair, and the UI is reached only through an SSM port-forward.
- **Secrets:** the database password is managed by RDS and read at boot; `tfvars` files are gitignored and a pre-commit hook blocks them.
- **Supply chain:** Trivy scan that fails on fixable high findings, pinned GitHub Actions by commit, Dependabot.
- **Audit:** CloudTrail with log validation (2 of 2 digests and 26 of 26 files verified).

**Reliability**

- Messages retry and move to a dead-letter queue after three receives, with an email alarm. The alarm fired 6 min 4 s after a bad message was sent.
- Backups run through AWS Backup with a cross-region copy. A full restore in another region took 16 min 6 s, with a data-loss window (RPO) of 43 s.
- An SLO fast-burn alert fired 2 min 36 s after I injected 5% failures locally.

**Cost**

- The environment is destroyed after each session. Billed usage across sessions was about six cents at the last check, and a budget alert watches the account.
- The node shuts itself down after 4 hours, but RDS bills until destroyed, so destroy is the real control.

## Likely interview questions

**Walk me through the project.** Use the 60-second pitch, then the seven-step flow from booking to email.

**Why k3s on one EC2 node instead of EKS?** EKS bills for the control plane even when idle, and this is a portfolio project that I destroy after each session. I wrote down what I would change for production: managed Kubernetes, private subnets, Multi-AZ RDS and per-pod identity.

**How do you keep one clinic's data away from another's?** PostgreSQL row-level security, forced on each table, with the policy comparing `clinic_id` to a setting the API applies at the start of every transaction. The application role is not a superuser and has no bypass. I tested it with a real database in CI.

**What happens if SQS delivers a message twice?** The worker checks DynamoDB for the audit record with a strongly consistent query before sending, and the audit write is conditional. The remaining gap is a crash between sending and recording, which I documented rather than hid.

**Why a dispatcher and an outbox instead of calling AWS from the API?** The booking and its reminder row commit together, so neither can exist alone. The API stays free of AWS credentials, so a compromised API cannot call AWS.

**How do you authenticate clinics?** Each clinic has a random 256-bit API key. Only its SHA-256 hash is stored, because a fast hash is enough for a high-entropy key. A `SECURITY DEFINER` function looks the key up, since the caller does not yet know which clinic it acts for.

**How does your CI/CD work with no AWS keys?** GitHub Actions assumes IAM roles through OIDC with a trust policy pinned to the repository. Pull requests get a read-only plan role; images are pushed to ECR from `main` only.

**What is GitOps here?** Argo CD syncs the manifests in the gitops repository to the cluster. A deploy is a pull request that changes the image tag to a commit SHA, and a rollback is a revert.

**What was the hardest bug?** The first real booking that produced no email. The worker logged only an error type, so I repeated the send as the node role through SSM and got AccessDenied on the recipient identity. In SES sandbox mode IAM checks the recipient too. Say that you proved the cause before changing anything.

**What would you change for production?** Managed Kubernetes, NAT or interface endpoints with private subnets, Multi-AZ RDS, per-pod identity, SES out of sandbox with a verified domain, automated backup replication, required reviews and image-tag automation.

**How do you handle failures and alerts?** Retries, a dead-letter queue after three receives, a CloudWatch alarm to SNS, and SLO burn-rate alerts. I also learned that an alert is proven only when a person receives it.

**How did you test disaster recovery?** I restored a backup into us-west-2 and timed it: 16 min 6 s for the restore, with an RPO of 43 s. The result is in ADR 0013.

**How did you keep costs down?** No NAT gateway, one small node, destroy after every session, a budget alert, and a 4-hour auto-shutdown on the node.

**What does Terraform manage, and what does it not?** The dev and DR environments and the supporting modules. The bootstrap resources have a local state file, which I back up outside Git. An SES identity I created from the CLI during debugging was not managed by Terraform, and I deleted it afterwards.

**How do you know the system works?** Unit tests (49), tenant-isolation tests against a real database, CI scans, and measured runs on AWS, with the numbers in the README and the ADRs.

**What did you learn?** Prove the alert path, assume at-least-once delivery, keep plans clean, write down what you have not verified, and test with a recipient that is not the sender.

## Limits, what I would change, and numbers to remember

Say the limits before you are asked. It shows you know the system, and it is the part of the write-up that readers trust most.

**Known limits**

- A single node, so there is no failover.
- SES is in sandbox mode: every recipient must be verified, and the test email landed in spam because there is no verified domain.
- Delivery is at-least-once; a crash between send and record can still send twice.
- Appointments cannot be rescheduled (the reminder does not move), and the UI cannot edit a patient's email.
- The daily backup schedule has not been observed running on its own; I started the backup by hand.
- Kubernetes Secret encryption at rest is unchecked, and CloudTrail has no alerting on top of it.
- Login is a clinic API key only, with no user accounts.

**Numbers to remember**

| Measurement | Result |
| --- | --- |
| Bad message to the dead-letter queue | 3 min 19 s |
| Alarm firing after the send | 6 min 4 s |
| Booking in the UI to the email sent | about 65 s |
| Full cross-region restore | 16 min 6 s, RPO 43 s |
| On-demand backup / cross-region copy | about 4 min / about 3.5 min |
| SLO fast-burn alert under 5% faults | pending after 19 s, firing after 2 min 36 s |
| Pod vs node requesting an instance-role token | timed out (curl exit 28) vs HTTP 200 |
| CloudTrail validation | 2 of 2 digests, 26 of 26 files |
| Automated tests | 49 |
| Billed cost at last check | about $0.06 |

The billed cost is from before the latest sessions and will be higher once billing catches up; check the README before you quote it.
