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
