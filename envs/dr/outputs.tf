output "kms_key_arn" {
  description = "Key that encrypts the copied snapshot and the restored instance"
  value       = aws_kms_key.dr.arn
}

output "db_subnet_group_name" {
  description = "Subnet group for the restored instance"
  value       = aws_db_subnet_group.dr.name
}

output "parameter_group_name" {
  description = "Parameter group that enforces TLS"
  value       = aws_db_parameter_group.dr.name
}

output "security_group_id" {
  description = "Security group of the restored instance"
  value       = aws_security_group.restore.id
}
