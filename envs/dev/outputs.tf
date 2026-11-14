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
output "k3s_instance_id" {
  description = "ID of the k3s node"
  value       = module.compute_k3s.instance_id
}

output "k3s_public_ip" {
  description = "Public IP of the k3s node"
  value       = module.compute_k3s.public_ip
}

output "k3s_ssm_connect_command" {
  description = "Command to open a shell on the node without SSH"
  value       = module.compute_k3s.ssm_connect_command
}
