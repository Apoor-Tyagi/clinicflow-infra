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
