# ADR 0009: Single-node k3s on EC2

Status: Accepted
Date: 2026-11-14

## Context

The workload needs a real Kubernetes cluster on AWS at a cost that fits a
learning budget. A managed control plane charges while idle.

## Decision

- Run k3s (pinned to v1.35.5+k3s1) on one EC2 instance, created by Terraform
  and destroyed after each session.
- Amazon Linux 2023, with the AMI looked up from the public SSM parameter.
- IMDSv2 required, metadata hop limit 1 so pods cannot borrow the node role,
  encrypted gp3 root volume, security group for ports 80 and 443 only.
- No SSH. Access is through Session Manager.
- A user_data script installs k3s, creates secrets, installs Argo CD v3.6.1 and
  applies the AWS Application, so the node deploys the API by itself.
- user_data_replace_on_change is on, so a script change replaces the instance.
- ECR login tokens last 12 hours, so a systemd timer refreshes the pull secret
  every 6 hours using the instance profile.
- Until the data tier exists, the lab Postgres runs on the node. Its password is
  generated at boot and never stored in Git.

## Alternatives considered

- EKS: managed, but the control plane costs money while idle.
- A t3.micro: its 1 GiB of memory is below the 1.47 GiB the stack used.

## Evidence from the first session

- Node Ready about 3 minutes after boot. Bootstrap finished about 4 minutes in.
- Argo CD showed the API Synced and Healthy, and /ready returned ready on the node.
- Memory on a t3.small: 1909 MiB total, 1473 MiB used, 251 MiB available, no swap.
- Largest pods: Argo application controller 117 MiB, API pods 51 MiB each,
  Argo server 44 MiB, Postgres 35 MiB. The rest is the OS, k3s and cache.

## Consequences

- A t3.small is the minimum and leaves little headroom. Monitoring will need a
  t3.medium.
- The k3s installer is run with curl and no checksum verification. Pinning the
  version limits what it installs. Production would verify a checksum.
- Checkov findings for open port 80 and detailed monitoring are skipped with reasons.
- Session cost: to be recorded from the Billing console.
