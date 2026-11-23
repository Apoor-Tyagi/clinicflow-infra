# 0016: A dispatcher turns booked appointments into reminder schedules

## Context

The API runs in a pod. The node requires IMDSv2 with a hop limit of 1, so a pod cannot
reach the instance role and has no AWS credentials. That was a deliberate choice
(ADR 0009). But booking an appointment has to end in a reminder email, and the path
there starts with an EventBridge schedule that only something with AWS credentials can
create.

## Decision

The API writes a row to a `reminders` table in the same transaction as the appointment
(a transactional outbox). A small dispatcher service runs on the node as a hardened
systemd unit next to the worker. It polls the table, creates one one-time schedule per
reminder in the reminders schedule group, and marks the row scheduled. When an
appointment is cancelled after its schedule exists, it deletes the schedule.

- The dispatcher uses its own database role. That role can read reminders across
  clinics and, column by column, the visit time and the patient email. It cannot read
  patient names or API keys and cannot delete rows. It does not bypass row-level
  security; it has its own policies.
- The node role may create and delete schedules only inside the reminders group, and
  may pass only the scheduler role, only to the scheduler service.
- Every step can be repeated. The schedule name comes from the appointment id, so a
  retry finds the schedule already there. A failed call leaves the row pending for the
  next poll. A cancel that arrives while a schedule is being created is cleaned up on
  the next poll.
- Schedules delete themselves after they run.
- A visit booked less than 24 hours ahead is reminded about a minute after the next
  poll, because EventBridge rejects a schedule in the past.

## Consequences

- The reminder can be late by up to one poll interval (15 seconds) plus the time to
  create the schedule. Reminders are 24 hours ahead, so this does not matter.
- A schedule carries the patient's email address as its input, so the schedule group
  is as sensitive as the queue. It is not logged anywhere.
- If the dispatcher is down, bookings still succeed and reminders wait in the table.
  Nothing is lost, and nothing is sent until it is back.
- Two dispatchers would be safe, because creating a schedule is idempotent, but only
  one runs.
- The first clinic is created with a random admin token generated on the node at boot.
  It is stored in a root-only file and is read once with Session Manager. This is
  adequate for a demo environment. A real deployment needs staff accounts.

## Not verified yet

This ADR describes the design. The "Verified on AWS" section is added after a real
booking from the UI has produced an email.

## Found on AWS: sandbox SES also checks the recipient identity

The first real booking from the UI reached the worker, and the worker could not send.
The worker logs only an error type, so the reason was read by repeating the send as the
node role. SES answered AccessDenied on `identity/<recipient>`: while an account is in
sandbox mode, SES evaluates `ses:SendEmail` against the recipient identity as well as the
sender. The policy listed only the sender, so it worked when the recipient was the sender
and failed for every other address. The policy now also allows identities in the account,
and the `ses:FromAddress` condition still limits the From address to the one sender.
The earlier sends that appeared to fail for "unverified recipients" were a separate,
real cause: the patient used a different, unverified address.
