data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "kms" {
  #checkov:skip=CKV_AWS_109: In a key policy, Resource "*" means this key only
  #checkov:skip=CKV_AWS_111: In a key policy, Resource "*" means this key only
  #checkov:skip=CKV_AWS_356: In a key policy, Resource "*" means this key only
  statement {
    sid       = "AccountAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

# A snapshot encrypted in the primary region cannot be copied without a key in the target region
resource "aws_kms_key" "dr" {
  description             = "clinicflow DR: encrypts snapshot copies and the restored instance"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "dr" {
  name          = "alias/clinicflow-dr"
  target_key_id = aws_kms_key.dr.key_id
}

resource "aws_db_subnet_group" "dr" {
  name       = "clinicflow-dr"
  subnet_ids = data.aws_subnets.default.ids
}

# Same TLS rule as the primary database
resource "aws_db_parameter_group" "dr" {
  name   = "clinicflow-dr"
  family = var.parameter_group_family

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

resource "aws_security_group" "restore" {
  #checkov:skip=CKV2_AWS_5: attached to the restored instance by the restore command, which Terraform does not manage
  name        = "clinicflow-dr-restore"
  description = "PostgreSQL from the operator address only, for the DR drill"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "operator" {
  security_group_id = aws_security_group.restore.id
  description       = "PostgreSQL from the operator address"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = var.operator_cidr
}

# Receives the daily backup copies from the primary region
resource "aws_backup_vault" "dr" {
  name        = "clinicflow-dr"
  kms_key_arn = aws_kms_key.dr.arn
}
