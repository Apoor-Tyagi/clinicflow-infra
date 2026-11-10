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
variable "github_sub_prefix" {
  type        = string
  description = "Immutable OIDC subject prefix of the GitHub repo allowed to assume the CI roles"
  default     = "repo:Apoor-Tyagi@201375503/clinicflow-infra@1449518229"
}

variable "github_app_sub_prefix" {
  type        = string
  description = "Immutable OIDC subject prefix of the app repository that may push images"

  validation {
    condition     = startswith(var.github_app_sub_prefix, "repo:")
    error_message = "Use the sub_claim_prefix from the GitHub API, starting with repo:."
  }
}