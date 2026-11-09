data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# --- KMS key used to encrypt data at rest across the project ---

data "aws_iam_policy_document" "kms" {
  #checkov:skip=CKV_AWS_109: In a key policy, Resource "*" means this key only
  #checkov:skip=CKV_AWS_111: In a key policy, Resource "*" means this key only
  #checkov:skip=CKV_AWS_356: In a key policy, Resource "*" means this key only
  statement {
    sid       = "EnableIAMPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = "${var.name} data encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}

# --- IAM role for the k3s EC2 node ---

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "k3s_node" {
  name               = "${var.name}-k3s-node"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_instance_profile" "k3s_node" {
  name = "${var.name}-k3s-node"
  role = aws_iam_role.k3s_node.name
}

# Shell access through Session Manager, so no SSH keys or open port 22
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# --- Least-privilege permissions for pulling images from ECR ---

data "aws_iam_policy_document" "k3s_node" {
  #checkov:skip=CKV_AWS_356: ecr:GetAuthorizationToken does not support resource-level permissions
  statement {
    sid       = "EcrLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "EcrPull"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = [
      "arn:aws:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/clinicflow-*"
    ]
  }
}

resource "aws_iam_role_policy" "k3s_node" {
  name   = "ecr-pull"
  role   = aws_iam_role.k3s_node.id
  policy = data.aws_iam_policy_document.k3s_node.json
}

# --- First SSM parameter (secrets will come later as SecureString) ---

resource "aws_ssm_parameter" "environment" {
  name  = "/${var.name}/app/environment"
  type  = "String"
  value = var.environment
}