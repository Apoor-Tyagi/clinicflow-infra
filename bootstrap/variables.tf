variable "region" {
  type        = string
  description = "Where resources are createde"
  default     = "us-east-1"

}

variable "alert_email" {
  type        = string
  description = "Where budget alerts go"
  default     = "apoorvtyagidewan@gmail.com"
}

variable "monthly_budget_usd" {
  type        = number
  description = "Budget limit"
  default     = 5

}
variable "github_repo" {
  type        = string
  description = "GitHub repository allowed to assume the CI roles, in owner/name form"
  default     = "Apoor-Tyagi/clinicflow-infra"
}