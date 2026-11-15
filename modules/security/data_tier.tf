# --- Node access to the master secret and the audit table, each scoped to one resource ---

data "aws_iam_policy_document" "data_tier" {
  statement {
    sid       = "ReadMasterSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.master_secret_arn]
  }

  statement {
    sid       = "DecryptMasterSecret"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.this.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.region}.amazonaws.com"]
    }
  }

  statement {
    sid       = "WriteAuditTable"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem", "dynamodb:Query"]
    resources = [var.audit_table_arn, "${var.audit_table_arn}/index/*"]
  }

  statement {
    sid       = "UseKeyForAuditTable"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [aws_kms_key.this.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["dynamodb.${data.aws_region.current.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "data_tier" {
  name   = "data-tier"
  role   = aws_iam_role.k3s_node.id
  policy = data.aws_iam_policy_document.data_tier.json
}
