variable "name" {
  type        = string
  description = "Name prefix, for example clinicflow-dev"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key that encrypts the queues"
}

variable "sender_email" {
  type        = string
  description = "Email address SES sends reminders from. AWS sends a confirmation link to it"

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.sender_email))
    error_message = "Use a real email address such as reminders@example.com."
  }
}

variable "max_receive_count" {
  type        = number
  description = "Failed receives before a message moves to the dead-letter queue"
}

variable "visibility_timeout_seconds" {
  type        = number
  description = "How long a received message stays hidden while the worker processes it"
}
