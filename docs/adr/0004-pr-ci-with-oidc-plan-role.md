# ADR 0004: Pull request CI with a read-only plan role

Status: Accepted
Date: 2026-11-10

## Context

Every change to the infrastructure code should be checked before it merges,
without giving CI the power to change AWS.

## Decision

- A GitHub Actions workflow runs on pull requests that touch infrastructure files.
- Job static-checks runs terraform fmt, validate without a backend, tflint, and
  checkov (version pinned).
- Job plan-dev authenticates with OIDC and runs terraform plan for the dev
  environment. Only this job has the id-token permission.
- The default token is read-only, and a newer push cancels an older run.
- Apply is manual and happens in short, deliberate sessions followed by destroy.

## Alternatives considered

- Auto-apply on merge: faster, but unsafe for an environment that costs money.
- Stored access keys: see ADR 0003.

## Consequences

- Plan output appears in public logs, so account IDs and ARNs are visible.
  Nothing secret may ever be printed.
- Documentation-only changes do not trigger the workflow because of the path filter.
- Early on, a pull request merged while its checks were still failing. A branch
  ruleset that requires the checks prevents that.
- Pre-commit hooks (formatting, large files, private keys, state and plan files)
  catch problems before they reach CI.
- Runner images and action versions change over time. Pin them deliberately.
