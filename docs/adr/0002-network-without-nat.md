# ADR 0002: Network without a NAT gateway

Status: Accepted
Date: 2026-11-08

## Context

The project runs on a learning budget. A NAT gateway has an hourly charge and a
per-GB charge even when idle, which does not fit short, destroyable sessions.

## Decision

- One VPC (10.0.0.0/16) across two availability zones, with two public subnets
  and two data subnets.
- The data route table has no internet route, so the database tier cannot reach
  or be reached from the internet.
- The k3s node sits in a public subnet. Its security group allows only ports
  80 and 443 in. There is no SSH, and access is through Session Manager.
- Free gateway endpoints for S3 and DynamoDB.
- The default security group is locked down with no rules.

## Alternatives considered

- NAT gateway with private application subnets: the production pattern, but costly.
- A NAT instance: cheaper, but one more machine to patch and secure.

## Consequences

- The node needs a public IP to download k3s, packages and images.
- Checkov findings for VPC flow logs and public IPs on the public subnets are
  skipped with reasons. Production would add flow logs.
- Production would use private application subnets, NAT or interface endpoints,
  and a managed Kubernetes control plane.
