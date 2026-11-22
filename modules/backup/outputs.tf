output "vault_name" {
  description = "Local backup vault"
  value       = aws_backup_vault.this.name
}

output "plan_id" {
  description = "ID of the daily backup plan"
  value       = aws_backup_plan.this.id
}
