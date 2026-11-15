variable "name" {
  type        = string
  description = "Table name, for example clinicflow-dev-audit"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key that encrypts the table"
}

variable "deletion_protection" {
  type        = bool
  description = "Block deletion of the table. Off for destroyable learning sessions, on in production"
}
