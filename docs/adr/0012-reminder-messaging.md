# ADR 0012: Reminder messaging with SQS, EventBridge Scheduler and SES

Status: Accepted. Written and planned, not yet exercised on AWS.
Date: 2026-11-21

## Context

Missed appointments cost clinics revenue, so the product sends reminders before
each appointment. Reminders must survive failures, must not be lost, and must not
expose patient data in logs or in the audit trail.

## Decision

- EventBridge Scheduler fires one schedule per appointment, in a schedule group.
  Its role can only send to the reminders queue and use the key through SQS.
- An SQS standard queue, encrypted with the project KMS key, holds the reminders.
  It uses long polling and a 60 second visibility timeout.
- After 3 failed receives a message moves to a dead-letter queue that keeps it for
  14 days. A redrive allow policy lets only the reminders queue use it.
- SES sends the email. The account is in sandbox mode, with a 200 message daily
  limit, so only verified addresses receive mail.
- A Python worker polls the queue, sends the email, writes a delivery record to the
  DynamoDB audit table, and deletes the message only after both succeeded.
- The audit key is the clinic, then reminder#appointment#time, written with an
  attribute_not_exists condition. A duplicate delivery is recognized and dropped.
- Recipient addresses and message bodies are never logged or stored. Only
  appointment identifiers and error types appear in logs.
- The worker role is limited to receive, delete and change visibility on one queue,
  ses:SendEmail on one identity restricted to one from-address, and the key through
  SQS only.
- The worker runs as a hardened systemd service on the node (DynamicUser, no new
  privileges, read-only filesystem, no capabilities), not as a pod. The node
  metadata hop limit stays at 1, so pods still cannot reach the node role.

## Alternatives considered

- A Kubernetes Deployment with hop limit 2: simple, but every pod would inherit the
  node role, including ECR, the master secret and the audit table.
- An IAM access key in a Secret: a long-lived credential, which this project avoids.
- Per-pod federation (IRSA or EKS Pod Identity): the production answer. On
  self-managed k3s it needs an OIDC issuer, so it was left out of scope.
- Direct SES calls from the API: simpler, but a failure would lose the reminder and
  block the request. The queue gives retries and a place to inspect failures.

## Consequences

- Delivery is at-least-once. If the worker crashes after sending and before the
  audit write, the message is received again and a second email can go out.
  Recording first would turn that into a possible lost email, which is worse.
- The service is not managed by Argo CD and does not scale like a Deployment.
- The bootstrap installs python3.12 if available and falls back to the default
  python3, and falls back to an unpinned boto3 if the pinned set fails. That keeps
  the node working at the cost of reproducibility.
- Sandbox mode limits the demo to verified recipients. Production access is a
  support request and was treated as out of scope.
- Nothing here has run on AWS yet. The first session must confirm the sender
  identity from the email AWS sends, send one test message, and check that the
  email arrives, the audit item exists and the dead-letter queue stays empty.

## Observed on AWS

- A valid reminder was sent through SES. The audit record was written and the
  message was deleted from the queue.
- A second delivery of the same message was recognized by the conditional write
  and dropped, so the audit table kept one record.
- A message that was not valid JSON was rejected on each of three receives, 60
  seconds apart, matching the visibility timeout. It then moved to the
  dead-letter queue with its body intact.
- The worker journal contained no email addresses.
- The worker used the node role from a host service. The role needed no
  permission beyond the scoped policy.
- In sandbox mode the sender and recipient both have to be verified. Re-creating
  an identity by hand outside Terraform caused a mismatch between the address in
  the variables file and the one in SES. Identities are owned by Terraform and
  should not be edited by hand.

## Observed duplicate email, and the change

On AWS, a message delivered a second time sent a second email, because the worker
sent first and recorded afterwards. The conditional write then dropped the second
record, but the email had already gone out.

The worker now looks up the audit record with a strongly consistent query before
sending, and drops the message without sending if the record exists. A failed
lookup keeps the message on the queue instead of sending blind. The lookup uses
dynamodb:Query, which the node role already allows. The conditional write stays as
a second line of defence against two workers handling the same message at once.

Verified on AWS on 2026-11-22. The same reminder was sent twice, 60 seconds apart.
One email arrived, the audit table held one record, and the worker log showed the
second delivery dropped as already sent.

A crash between the send and the record can still produce one duplicate, so
delivery remains at-least-once.

## Dead-letter queue alarm

A message that fails three times moves to the dead-letter queue, where it waited
silently. A CloudWatch alarm now fires when the queue holds any message, and an SNS
topic emails the operator.

The topic is encrypted with the project key, not the AWS-managed SNS key, because
CloudWatch cannot publish to a topic encrypted with an AWS-managed key. The key
policy gained one statement that lets cloudwatch.amazonaws.com use the key, limited
to this account. The recipient address is a variable that defaults to empty and is
set only in the local tfvars file, so it never enters Git.

Verified on AWS on 2026-11-22. A malformed message was received three times and
reached the dead-letter queue 3 min 19 s after it was sent. The alarm fired 6 min
4 s after it was sent, and the email arrived.

An email subscription starts unconfirmed, and SNS silently drops alerts until the
confirmation link is clicked. The first apply of each session sends that link, and
it is easy to miss. The alarm email only arrived after the link was confirmed.
