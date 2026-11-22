# 0014: Scheduled backups with a cross-region copy

## Context

The disaster recovery drill (ADR 0013) showed that a restore works, but the recovery
point depended on someone copying a snapshot by hand. Nothing took backups on a
schedule, so after a real incident the newest usable copy could be arbitrarily old.

## Decision

An AWS Backup plan in modules/backup takes a daily backup of the RDS instance at
03:00 UTC and copies it to a vault in us-west-2. Backups are kept for 7 days in each
region.

- The destination vault lives in envs/dr, next to the DR key that encrypts it. That
  environment outlives the dev environment, which is destroyed after each session.
- The destination vault and key ARNs are optional variables that default to empty,
  so CI can plan without them. They are set in the local tfvars file after envs/dr
  is applied, and with them empty the plan simply takes no cross-region copy.
- The local vault uses force_destroy, so a session teardown is not blocked by
  leftover recovery points.
- The backup role gets explicit permission on both keys instead of relying on the
  managed policy alone.

Apply order: envs/dr first, copy its backup_vault_arn and kms_key_arn outputs into
the dev tfvars, then apply dev.

## Consequences

- The recovery point becomes up to about 24 hours, replacing the 43 seconds measured
  in the drill, which used a snapshot taken moments before the copy. The 43 seconds
  was the best case, not the guarantee.
- Dev is destroyed after each session, so backups only accumulate in an environment
  that stays up. The copy in the DR vault outlives dev until its 7 days expire.
- The DR key and vault exist as long as envs/dr is applied, and cost a little.
- The DR vault also uses force_destroy, so tearing down envs/dr is not blocked by copies that have not expired yet.

## Not yet verified

This is validated and scanned but has not run on AWS. The first apply should confirm
that a backup completes, that the copy appears in the DR vault, and that the role's
key permissions are enough for the cross-region copy. If the copy fails with a key
error, the fix is in the role's key policy, not in the plan.
