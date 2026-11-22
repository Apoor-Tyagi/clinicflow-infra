# ADR 0013: Disaster recovery drill with a cross-region snapshot

Status: Accepted. Exercised on AWS on 2026-11-22.

## Context

The database lives in one region. A regional failure would lose it unless a copy
exists elsewhere. Recovery has to be measured, not assumed.

## Decision

- A separate environment, envs/dr, holds what a restore needs before an incident:
  a KMS key in us-west-2, a subnet group over the default VPC, a parameter group
  that enforces TLS, and a security group.
- The snapshot, the copy and the restore are timed CLI commands, because snapshots
  are not normal Terraform objects and the timing is the point.
- The restored instance was reachable from one operator address (/32) for about
  ten minutes, a deliberate and time-boxed exception to the private data subnets
  in ADR 0002. It held a synthetic marker row and no patient data.
- Everything, in both regions, was destroyed afterwards.

## Measured results (db.t4g.micro, nearly empty database)

- Snapshot: 3 min 6 s.
- Cross-region copy: 1 min 35 s.
- Restore to available: 10 min 25 s.
- Master password reset: 1 min 58 s.
- First successful query 27 s after that.
- Recovery steps in AWS time: 16 min 6 s. Wall clock from the snapshot to the
  first query was 22 min, which includes about 7 minutes of operator pause.
- RPO of the drill: 43 seconds, from the marker commit to the snapshot time.
  A real outage has an RPO equal to the age of the newest snapshot.
- The marker row came back with its original timestamp.

## Findings

- The RDS master user sees all rows despite FORCE ROW LEVEL SECURITY. A query
  with no clinic set returned the marker row. Isolation therefore holds for the
  application role, not for the operator credential. The application role came
  across with rolbypassrls false. Its behaviour could not be re-tested on the
  copy, because its password lived in a Kubernetes Secret on the destroyed node.
- A restored instance runs without enforced TLS until it is rebooted, because
  rds.force_ssl is a static parameter (pending-reboot). The recovery runbook
  needs a reboot, or clients must enforce TLS themselves.
- A restore keeps the old master password. The managed secret is gone with the
  source, so the runbook needs a reset step.
- The copy needs a KMS key in the destination region, so the key and network
  must exist before the incident.
- The copy had to finish before the source environment was destroyed, because
  destroying the source key blocks use of the encrypted snapshot.

## Consequences

- Times scale with data size, so these figures do not predict a real clinic.
- Production would use automated backup replication for continuous protection,
  and a runbook with the reboot, the password reset and an application role
  isolation test after every restore.
- Cost was a few minutes of two small instances, snapshot storage and one
  cross-region copy. The Billing figure is to be added.
