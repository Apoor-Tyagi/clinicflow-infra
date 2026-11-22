variable "region" {
  type        = string
  description = "AWS region for the dev environment"
  default     = "us-east-1"
}

variable "reminder_sender_email" {
  type        = string
  description = "Address SES sends reminder emails from. Set it in terraform.tfvars, which is not committed"
}

variable "alarm_email" {
  type        = string
  default     = ""
  description = "Address for dead-letter queue alerts. Set it in terraform.tfvars, never in Git"
}

variable "dr_backup_vault_arn" {
  type        = string
  default     = ""
  description = "Vault in the DR region (output of envs/dr). Empty means no cross-region copy"
}

variable "dr_kms_key_arn" {
  type        = string
  default     = ""
  description = "Key of the DR vault (output of envs/dr)"
}
