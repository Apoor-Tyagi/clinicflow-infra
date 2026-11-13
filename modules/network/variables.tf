variable "name" {
  type        = string
  description = "Name prefix for all network resources, for example clinicflow-dev"

}
variable "vpc_cidr" {
  type        = string
  description = "IP range for the VPC, for example 10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block such as 10.0.0.0/16."
  }
}
variable "azs" {
  type        = list(string)
  description = "AvAvailability zones to use, one per subnet pair"

}
variable "public_subnet_cidrs" {
  type        = list(string)
  description = "IDR blocks for public subnets, one per availability zone"
}
variable "data_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private data subnets, one per availability zone"

}
