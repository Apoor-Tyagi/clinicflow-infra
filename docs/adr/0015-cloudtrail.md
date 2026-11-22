# 0015: CloudTrail in the bootstrap stack

## Context

Nothing recorded who called which AWS API in the account. After an incident, or a
mistake, there would be no way to reconstruct what happened. The threat model listed
this as a gap.

## Decision

A multi-region trail records management events to a dedicated S3 bucket, with log
file validation on so tampering can be detected.

- It lives in bootstrap, next to the state bucket. The dev environment is destroyed
  after each session, and the audit trail must not disappear with it.
- The bucket blocks public access, requires TLS, is versioned, and expires logs
  after 90 days, so storage cost stays at pennies.
- The first management-event trail in an account is free.
- The bucket policy limits CloudTrail to this trail through aws:SourceArn.

## Trade-offs

- Logs use S3's default encryption (SSE-S3), not a customer key. A customer key
  would cost about $1 a month while bootstrap exists, which is a fifth of the monthly
  budget. The checkov rules that ask for a customer key are skipped with that reason.
  Switching later means adding a key with a CloudTrail policy and setting kms_key_id.
- No CloudWatch Logs stream and no alerting. The trail is a record to search after
  the fact, not detection.
- No cross-region replication of the logs.

## Verified on AWS (2026-11-22)

The trail was applied and delivered 101 log files within about two hours. Running
aws cloudtrail validate-logs over the first hour found 2 of 2 digest files valid
and 26 of 26 log files valid, so tampering between delivery and validation would
have been detected. Nothing alerts on the trail yet.
