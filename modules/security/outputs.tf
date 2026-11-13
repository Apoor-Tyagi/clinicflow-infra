output "kms_key_arn" {
  description = "ARN of the project KMS key"
  value       = aws_kms_key.this.arn
}

output "kms_key_id" {
  description = "ID of the project KMS key"
  value       = aws_kms_key.this.key_id
}

output "k3s_instance_profile_name" {
  description = "Instance profile to attach to the k3s EC2 node"
  value       = aws_iam_instance_profile.k3s_node.name
}

output "k3s_role_arn" {
  description = "ARN of the k3s node IAM role"
  value       = aws_iam_role.k3s_node.arn
}
