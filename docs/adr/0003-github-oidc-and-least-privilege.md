# ADR 0003: GitHub OIDC and least-privilege roles

Status: Accepted
Date: 2026-11-09

## Context

CI needs to run terraform plan against AWS. Long-lived access keys in GitHub
secrets can leak and never expire.

## Decision

- Register GitHub as an OIDC identity provider in the account (bootstrap).
- The plan role has the AWS ReadOnlyAccess policy plus read and write access to
  the state bucket only, which plans need for the lock file.
- The trust policy requires the audience sts.amazonaws.com and a subject that
  matches this repository.
- GitHub now issues an immutable subject that contains numeric owner and
  repository IDs (repo:OWNER@ID/REPO@ID). The trust policy uses that form.
  The IDs come from gh api repos/OWNER/REPO/actions/oidc/customization/sub.
- The k3s node role has Session Manager access and ECR pull access limited to
  repositories named clinicflow-*.
- One customer-managed KMS key with rotation. Configuration values use SSM
  Parameter Store, which is free, instead of Secrets Manager.

## Alternatives considered

- Access keys in GitHub secrets: simple, but long-lived credentials.
- Running Terraform only from a laptop: no CI safety net.

## Consequences

- The first trust policy used the repository name, and GitHub sent the immutable
  form, so every run failed with "Not authorized to perform
  sts:AssumeRoleWithWebIdentity". The fix was to read the real claim format.
- A placeholder value passed weak variable validation once. The variable now
  has a regex that requires numeric IDs, so the mistake fails at plan time.
- ReadOnlyAccess is broad. A production version would narrow it.
