variable "name" {
  type        = string
  description = "Identifier prefix, lowercase, for example clinicflow-dev"
}

variable "vpc_id" {
  type        = string
  description = "VPC the database runs in"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Data subnets in at least two availability zones"
}

variable "allowed_security_group_id" {
  type        = string
  description = "Security group of the application tier that may connect on 5432"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key that encrypts storage and the master secret"
}

variable "engine_version" {
  type        = string
  description = "PostgreSQL engine version, for example 17.4"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.engine_version))
    error_message = "Use a real version such as 17.4 (look it up with aws rds describe-db-engine-versions)."
  }
}

variable "parameter_group_family" {
  type        = string
  description = "Parameter group family matching the engine, for example postgres17"

  validation {
    condition     = can(regex("^postgres[0-9]+$", var.parameter_group_family))
    error_message = "Use a family such as postgres17."
  }
}

variable "instance_class" {
  type        = string
  description = "DB instance class, for example db.t4g.micro"

  validation {
    condition     = startswith(var.instance_class, "db.")
    error_message = "Use an RDS instance class that starts with db."
  }
}

variable "allocated_storage_gb" {
  type        = number
  description = "Storage in GiB"
}

variable "backup_retention_days" {
  type        = number
  description = "Days of automated backups, 1 to 35"
}

variable "multi_az" {
  type        = bool
  description = "Run a standby in a second availability zone"
}

variable "deletion_protection" {
  type        = bool
  description = "Block deletion and take a final snapshot when destroyed. Off for learning sessions"
}
