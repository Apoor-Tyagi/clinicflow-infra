output "vpc_id" {
  description = "ID of the dev VPC"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.network.public_subnet_ids
}

output "data_subnet_ids" {
  description = "IDs of the private data subnets"
  value       = module.network.data_subnet_ids
}
