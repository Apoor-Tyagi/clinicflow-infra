# Runbook: restore the database in another region

Use this when the primary region is unavailable and the database must be brought
up in us-west-2. The drill that produced the timings is in
[ADR 0013](../adr/0013-disaster-recovery-drill.md).

## What you need before an incident

These exist in envs/dr and must be applied beforehand. They cannot be created
quickly during an outage if the primary region's Terraform state is unreachable.

- A KMS key in us-west-2 (output: kms_key_arn)
- A DB subnet group (output: db_subnet_group_name)
- A parameter group that enforces TLS (output: parameter_group_name)
- A security group (output: security_group_id)
- A recent snapshot of the primary database, copied to us-west-2

The recovery point is the age of the newest copied backup. A daily backup plan
(modules/backup, ADR 0014) copies the database to the vault in envs/dr at 03:00
UTC, so it should be under about 24 hours. That plan has not run on AWS yet, so
treat it as unproven until a copy has been seen in the DR vault.

## Steps and measured times

Times are from a nearly empty db.t4g.micro and scale with data size.

1. Copy the newest snapshot to us-west-2 with the DR key (1 min 35 s). Skip this
   if a copy already exists. If the source region is down, the copy cannot be made,
   so the copy must have happened earlier.
2. Restore a new instance from the copied snapshot, using the subnet group,
   parameter group and security group from envs/dr (10 min 25 s to available).
3. Reset the master password with a freshly generated value (about 2 min). A
   restore keeps the old password, and the managed secret belongs to the source.
4. Reboot the instance so rds.force_ssl takes effect. This step is untested: the drill
   never rebooted, and the need for it is inferred from the parameter's pending-reboot status.
   Until the reboot the restored instance does not enforce TLS, because the
   parameter is static. Connect with sslmode=require in the meantime.
5. Connect and read a known row to confirm the data is intact (27 s after the
   password reset in the drill).

Measured recovery steps in AWS time: 16 min 6 s. Add detection and decision time.

## After the restore

- Row-level security: the master user sees every row, so it is not a test of
  isolation. Recreate the application role password, connect as the application
  role, and confirm that a query with no clinic set returns nothing and that one
  clinic cannot read another's rows. This was not re-tested in the drill, because
  the application role's password lived only in a Kubernetes Secret on the
  destroyed node.
- Point the application at the new endpoint through its secret, not through Git.
- Remove any temporary public access and any operator address rule once finished.

## Cleanup after a drill

Delete the restored instance with its automated backups, then both snapshots, then
destroy envs/dr. The security group can only be deleted after the instance is gone.
The source KMS key must stay usable until the copy has finished, so never destroy
the source environment first.

## Known gaps

- Scheduled backups exist in code but have not run on AWS, so the recovery point is unproven.
- The restore commands are not scripted. The drill ran them by hand.
- The application role's isolation after a restore has not been re-tested.
