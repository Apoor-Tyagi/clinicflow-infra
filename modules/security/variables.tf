variable "name" {
  type        = string
  description = "Name prefix for security resources, for example clinicflow-dev"
}

variable "environment" {
  type        = string
  description = "Environment name, for example dev"
}

variable "master_secret_arn" {
  type        = string
  description = "ARN of the RDS-managed master secret the node may read"
}

variable "audit_table_arn" {
  type        = string
  description = "ARN of the DynamoDB audit table the node may write to"
}

variable "reminders_queue_arn" {
  type        = string
  description = "ARN of the reminders queue the worker consumes"
}

variable "sender_identity_arn" {
  type        = string
  description = "ARN of the SES identity the worker sends from"
}

variable "sender_email" {
  type        = string
  description = "Address the worker is allowed to send as"
}
