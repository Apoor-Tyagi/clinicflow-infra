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