output "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state"
  value       = aws_s3_bucket.state.id

}
output "state_bucket_arn" {
  description = "ARN of the Terraform state bucket"
  value       = aws_s3_bucket.state.arn
}
output "github_plan_role_arn" {
  description = "ARN of the role GitHub Actions assumes to run terraform plan"
  value       = aws_iam_role.github_plan.arn
}