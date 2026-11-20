# Messages that failed too many times land here for inspection
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-reminders-dlq"
  kms_master_key_id         = var.kms_key_arn
  message_retention_seconds = 1209600 # 14 days, the maximum
}

resource "aws_sqs_queue" "reminders" {
  name                       = "${var.name}-reminders"
  kms_master_key_id          = var.kms_key_arn
  visibility_timeout_seconds = var.visibility_timeout_seconds
  receive_wait_time_seconds  = 20 # long polling, so the worker is not billed for empty polls

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.reminders.arn]
  })
}

# Sandbox accounts can only send to verified addresses. This sends the confirmation link
resource "aws_sesv2_email_identity" "sender" {
  email_identity = var.sender_email
}

# --- EventBridge Scheduler: delivers reminder messages to the queue on time ---

data "aws_iam_policy_document" "scheduler_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${var.name}-reminder-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_trust.json
}

data "aws_iam_policy_document" "scheduler_send" {
  statement {
    sid       = "SendToRemindersQueue"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.reminders.arn]
  }

  statement {
    sid       = "UseQueueKey"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [var.kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["sqs.${data.aws_region.current.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "scheduler_send" {
  name   = "send-to-reminders-queue"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler_send.json
}

data "aws_region" "current" {}

resource "aws_scheduler_schedule_group" "reminders" {
  name = "${var.name}-reminders"
}
