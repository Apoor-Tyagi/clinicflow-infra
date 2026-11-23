variable "name" {
  type        = string
  description = "Name prefix, for example clinicflow-dev"
}

variable "vpc_id" {
  type        = string
  description = "VPC the node runs in"
}

variable "subnet_id" {
  type        = string
  description = "Public subnet for the node"
}

variable "instance_profile_name" {
  type        = string
  description = "IAM instance profile attached to the node"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type with at least 2 GiB of memory, for example t3.small"
}

variable "architecture" {
  type        = string
  description = "CPU architecture of the instance type: x86_64 (t3) or arm64 (t4g)"

  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "architecture must be x86_64 or arm64."
  }
}

variable "root_volume_gb" {
  type        = number
  description = "Root volume size in GiB"
}

variable "k3s_version" {
  type        = string
  description = "Pinned k3s release, for example v1.35.5+k3s1"
}

variable "argocd_version" {
  type        = string
  description = "Pinned Argo CD release tag, matching your local cluster"
}

variable "gitops_raw_url" {
  type        = string
  description = "Raw GitHub URL of the gitops repo main branch, without a trailing slash"
}

variable "db_host" {
  type        = string
  description = "Hostname of the RDS database"
}

variable "db_master_secret_arn" {
  type        = string
  description = "Secrets Manager secret that holds the RDS master credentials"
}

variable "app_raw_url" {
  type        = string
  description = "Raw GitHub URL of the app repo main branch, without a trailing slash"
}

variable "queue_url" {
  type        = string
  description = "URL of the reminders queue the worker consumes"
}

variable "sender_email" {
  type        = string
  description = "Address the worker sends reminder emails from"
}

variable "audit_table_name" {
  type        = string
  description = "DynamoDB table the worker writes delivery records to"
}

variable "queue_arn" {
  type        = string
  description = "ARN of the reminders queue that schedules deliver to"
}

variable "schedule_group_name" {
  type        = string
  description = "EventBridge Scheduler group the dispatcher creates reminder schedules in"
}

variable "scheduler_role_arn" {
  type        = string
  description = "Role EventBridge Scheduler assumes to send to the queue"
}

variable "migration_files" {
  type        = list(string)
  description = "Database migration files in the app repo, applied in this order"
  default     = ["001_tenant_model.sql", "002_api_access.sql", "003_dispatcher.sql"]
}
