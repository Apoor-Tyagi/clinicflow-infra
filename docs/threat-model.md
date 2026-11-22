# Threat model

A STRIDE review of ClinicFlow as built. It lists what could go wrong, the control
that exists today, and the gap that remains. Items marked "not verified" were
reasoned about but not tested.

## Scope and assets

In scope: the API, the reminder worker, the database, the queue, the audit table,
the CI pipeline, and the single k3s node they run on.

Assets worth protecting, most sensitive first:

1. Patient contact details and appointment times (in PostgreSQL).
2. Separation between clinics (one clinic must never read another's rows).
3. The AWS account, reached through the CI role and the node's instance role.
4. Availability of reminders.

## Trust boundaries

- Internet to the API (the only intended public entry).
- Pods to the node's instance metadata and instance role.
- The node to RDS, SQS, SES and DynamoDB.
- GitHub Actions to AWS.
- The primary region to the DR region.

## Threats and controls

### Tenant isolation (PostgreSQL)

| STRIDE | Threat | Control today | Gap |
|---|---|---|---|
| Information disclosure | A query for one clinic returns another clinic's rows | Row-level security with FORCE on every tenant table; the app connects as a separate role that RLS applies to; isolation tests run in CI against real Postgres | The master user bypasses RLS by design, so its credentials are as sensitive as all tenant data |
| Information disclosure | A request that sets no clinic reads everything | A query with no clinic set returns nothing (tested) | Isolation of the restored database was not re-tested after the DR drill |
| Information disclosure | Traffic to the database is read in transit | rds.force_ssl is set | The parameter is static and needs a reboot; whether the primary enforces it after a reboot was inferred, not verified |
| Tampering | A bug lets one tenant write into another | RLS applies to writes through the same policies | Policies are only as good as the tests; new tables must be added to the isolation tests |

### Reminder pipeline (SQS, worker, SES, DynamoDB)

| STRIDE | Threat | Control today | Gap |
|---|---|---|---|
| Tampering | A forged or malformed message reaches the worker | Messages are parsed strictly; bad messages stay on the queue and move to the dead-letter queue after 3 receives | No message signing; trust rests on who can send to the queue (IAM) |
| Repudiation | Nobody can show whether a reminder was sent | A DynamoDB audit record per reminder, written after the send | A crash between the send and the record can lose the record |
| Information disclosure | The audit table leaks patient addresses | The audit record never holds the recipient address (tested) | Logs were reviewed for this only informally |
| Denial of service | A poison message blocks the queue | Visibility timeout and a dead-letter queue | No alarm on dead-letter queue depth yet |
| Denial of service | A duplicate delivery sends two emails | The worker looks up the audit record with a strongly consistent query before sending; a conditional write is the second defence | Delivery is at-least-once. This was proven by unit tests, not yet on AWS |
| Elevation of privilege | The worker abuses its role | Runs as a hardened systemd service; the IAM policy allows only the specific queue, SES sender, and PutItem and Query on the audit table | It uses the node's instance role, so a compromised worker holds the node's permissions, not a role of its own |

### The k3s node

| STRIDE | Threat | Control today | Gap |
|---|---|---|---|
| Elevation of privilege | A pod steals the instance role through metadata | IMDSv2 required with a hop limit of 1, so pods cannot reach it | Not re-tested from inside a pod |
| Spoofing | Someone logs in to the node | No SSH and no key pair; access only through Session Manager under IAM | Session activity is not logged to a separate store |
| Information disclosure | Secrets are read from the cluster | The application database password is created at bootstrap and held in a Kubernetes Secret | Not verified whether Kubernetes Secrets are encrypted at rest in k3s; assume they are not |
| Denial of service | The single node fails | A new node can be built from Terraform and Argo CD | No high availability; the node is a single point of failure by design, for cost |
| Tampering | A malicious image runs | Images are scanned with Trivy in CI, with a gate; pushes happen only from main | No admission control (for example Kyverno) to stop unsigned or unscanned images in the cluster |

### CI and AWS access

| STRIDE | Threat | Control today | Gap |
|---|---|---|---|
| Spoofing | Another repository assumes the AWS role | OIDC trust is limited to this repository's immutable IDs; no stored AWS keys | Not re-audited since the policy was written |
| Elevation of privilege | A pull request changes infrastructure | PR plans use a read-only plan role; changes are applied by hand | The apply step is manual and depends on the operator's own credentials |
| Tampering | Unreviewed code reaches main | Branch rulesets protect main; checks must pass; pre-commit blocks state, plan and tfvars files | Single maintainer, so review is self-review |
| Tampering | A dependency or Action is compromised | Dependabot proposes updates for Actions and Terraform providers | Actions are pinned by version tag, not by commit hash |

### Disaster recovery

| STRIDE | Threat | Control today | Gap |
|---|---|---|---|
| Information disclosure | A copied snapshot is read in the DR region | Snapshots are copied encrypted with a DR key that has an explicit policy | None known |
| Information disclosure | A restored database is left open | The DR security group allows only a single operator address; the runbook says to remove it afterwards | Removal depends on following the runbook |
| Denial of service | No recent copy exists when needed | Runbook documents the manual copy | Scheduled backups with a cross-region copy exist in code (ADR 0014) but have not run on AWS |

## Not covered

- No CloudTrail trail or account-level detection is configured, so there is no audit of who did what in AWS.
- No WAF or rate limiting in front of the API.
- SES is in sandbox mode, so abuse and bounce handling are not exercised.
- No penetration test and no formal review beyond this document.

## Priorities

1. Scheduled snapshots with a cross-region copy (closes the recovery point gap).
2. CloudTrail with logs to a protected bucket.
3. An alarm on dead-letter queue depth.
4. Pin GitHub Actions by commit hash.
5. Verify Kubernetes Secret encryption at rest, and turn it on if it is off.
6. Re-test pod access to instance metadata from inside a pod.
