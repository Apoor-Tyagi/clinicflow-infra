variable "region" {
  type        = string
  description = "Recovery region. The state stays in us-east-1"
  default     = "us-west-2"
}

variable "parameter_group_family" {
  type        = string
  description = "Parameter group family of the restored engine"
  default     = "postgres17"

  validation {
    condition     = can(regex("^postgres[0-9]+$", var.parameter_group_family))
    error_message = "Use a family such as postgres17."
  }
}

variable "operator_cidr" {
  type        = string
  description = "Your own public address as a /32. The only source allowed to reach the restored database during the drill"

  validation {
    condition     = can(cidrhost(var.operator_cidr, 0)) && endswith(var.operator_cidr, "/32")
    error_message = "Use a single address in CIDR form, for example 203.0.113.7/32."
  }
}
