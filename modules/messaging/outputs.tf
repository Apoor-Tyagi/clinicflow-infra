output "queue_url" {
  description = "URL of the reminders queue"
  value       = aws_sqs_queue.reminders.url
}

output "queue_arn" {
  description = "ARN of the reminders queue"
  value       = aws_sqs_queue.reminders.arn
}

output "dlq_arn" {
  description = "ARN of the dead-letter queue"
  value       = aws_sqs_queue.dlq.arn
}

output "sender_identity_arn" {
  description = "ARN of the SES sender identity"
  value       = aws_sesv2_email_identity.sender.arn
}
