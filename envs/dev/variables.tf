variable "region" {
  type        = string
  description = "AWS region for the dev environment"
  default     = "us-east-1"
}

variable "reminder_sender_email" {
  type        = string
  description = "Address SES sends reminder emails from. Set it in terraform.tfvars, which is not committed"
}
