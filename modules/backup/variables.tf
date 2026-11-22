variable "name" {
  type        = string
  description = "Name prefix, for example clinicflow-dev"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key that encrypts the local vault"
}

variable "db_arn" {
  type        = string
  description = "ARN of the RDS instance to back up"
}

variable "schedule" {
  type        = string
  default     = "cron(0 3 * * ? *)"
  description = "When the backup runs, in UTC. The default is 03:00 UTC every day"
}

variable "retention_days" {
  type        = number
  default     = 7
  description = "Days a backup is kept in the local vault"
}

variable "copy_retention_days" {
  type        = number
  default     = 7
  description = "Days a copy is kept in the destination vault"
}

variable "destination_vault_arn" {
  type        = string
  default     = ""
  description = "Vault in the DR region. Empty means no cross-region copy"
}

variable "destination_kms_key_arn" {
  type        = string
  default     = ""
  description = "Key of the destination vault, so the backup role may use it"
}
