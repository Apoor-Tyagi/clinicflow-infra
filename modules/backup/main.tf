resource "aws_backup_vault" "this" {
  name        = "${var.name}-backup"
  kms_key_arn = var.kms_key_arn
  # The dev environment is destroyed after each session. Without this, leftover
  # recovery points would block the destroy
  force_destroy = true
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.name}-backup"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# Explicit key access, so the backup and the cross-region copy do not depend on defaults
data "aws_iam_policy_document" "keys" {
  statement {
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey", "kms:CreateGrant"]
    resources = compact([var.kms_key_arn, var.destination_kms_key_arn])
  }
}

resource "aws_iam_role_policy" "keys" {
  name   = "keys"
  role   = aws_iam_role.backup.id
  policy = data.aws_iam_policy_document.keys.json
}

resource "aws_backup_plan" "this" {
  name = "${var.name}-daily"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.schedule

    lifecycle {
      delete_after = var.retention_days
    }

    dynamic "copy_action" {
      for_each = var.destination_vault_arn == "" ? [] : [1]

      content {
        destination_vault_arn = var.destination_vault_arn

        lifecycle {
          delete_after = var.copy_retention_days
        }
      }
    }
  }
}

resource "aws_backup_selection" "db" {
  name         = "${var.name}-db"
  plan_id      = aws_backup_plan.this.id
  iam_role_arn = aws_iam_role.backup.arn
  resources    = [var.db_arn]
}
