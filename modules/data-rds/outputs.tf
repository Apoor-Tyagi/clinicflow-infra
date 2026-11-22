output "address" {
  description = "Hostname of the database"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port of the database"
  value       = aws_db_instance.this.port
}

output "master_secret_arn" {
  description = "Secrets Manager secret that holds the master password"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "security_group_id" {
  description = "Security group of the database"
  value       = aws_security_group.db.id
}

output "instance_arn" {
  description = "ARN of the database instance"
  value       = aws_db_instance.this.arn
}
