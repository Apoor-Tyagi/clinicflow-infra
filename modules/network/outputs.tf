output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "data_subnet_ids" {
  description = "IDs of the private data subnets"
  value       = aws_subnet.data[*].id
}

output "data_route_table_id" {
  description = "ID of the data route table"
  value       = aws_route_table.data.id
}