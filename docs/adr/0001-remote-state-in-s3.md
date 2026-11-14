# ADR 0001: Remote Terraform state in S3

Status: Accepted
Date: 2026-11-08

## Context

Terraform state records which real resources belong to the code. It can hold
sensitive values, and CI needs to read it. State on one laptop is easy to lose
and impossible for a pipeline to use.

## Decision

- Keep state in an S3 bucket named clinicflow-tfstate-ACCOUNT-us-east-1.
- The bucket has versioning, AES256 encryption, all four public access blocks,
  a policy that denies non-TLS requests, and a lifecycle rule that expires old
  versions after 90 days.
- Use S3 native locking (use_lockfile), so no DynamoDB lock table is needed.
- The bucket is created by a separate bootstrap configuration that uses local
  state, because the bucket cannot store the state of its own creation.
- prevent_destroy is set on the bucket.

## Alternatives considered

- Local state: simple, but not shareable and easy to lose.
- Terraform Cloud: works, but adds an account and a dependency for a small project.
- S3 plus a DynamoDB lock table: the older pattern, which adds a resource to manage.

## Consequences

- The bootstrap state file lives on one machine and is gitignored. It must be
  backed up. Losing it means re-importing the bucket, budget and roles.
- Checkov findings for access logging, replication, event notifications and KMS
  encryption are skipped with written reasons. A production version would add
  logging, cross-region replication and a customer-managed key.
