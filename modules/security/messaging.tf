# --- Worker access to the reminders queue and the SES sender, each scoped to one resource ---

data "aws_iam_policy_document" "messaging" {
  statement {
    sid    = "ConsumeRemindersQueue"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
    ]
    resources = [var.reminders_queue_arn]
  }

  statement {
    sid       = "UseKeyForQueue"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.this.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["sqs.${data.aws_region.current.region}.amazonaws.com"]
    }
  }

  statement {
    sid    = "ManageReminderSchedules"
    effect = "Allow"
    actions = [
      "scheduler:CreateSchedule",
      "scheduler:DeleteSchedule",
    ]
    resources = [
      "arn:aws:scheduler:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:schedule/${var.schedule_group_name}/*"
    ]
  }

  statement {
    sid       = "HandSchedulerItsRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [var.scheduler_role_arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["scheduler.amazonaws.com"]
    }
  }

  statement {
    sid     = "SendReminderEmail"
    effect  = "Allow"
    actions = ["ses:SendEmail"]
    # While the SES account is in sandbox mode, SES also checks the permission against the
    # recipient's identity, so the sender alone is not enough. The condition below still
    # restricts the From address to the one sender.
    resources = [
      var.sender_identity_arn,
      "arn:aws:ses:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:identity/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "ses:FromAddress"
      values   = [var.sender_email]
    }
  }
}

resource "aws_iam_role_policy" "messaging" {
  name   = "messaging"
  role   = aws_iam_role.k3s_node.id
  policy = data.aws_iam_policy_document.messaging.json
}
