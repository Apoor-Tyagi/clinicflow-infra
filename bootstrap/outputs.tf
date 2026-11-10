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
output "github_ecr_push_role_arn" {
  description = "Role the app repo assumes to push images to ECR"
  value       = aws_iam_role.github_ecr_push.arn
}

output "ecr_repository_url" {
  description = "URL of the clinicflow-api ECR repository"
  value       = aws_ecr_repository.api.repository_url
}