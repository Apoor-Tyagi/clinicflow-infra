resource "aws_ecr_repository" "api" {
  #checkov:skip=CKV_AWS_136: AES256 encryption is free; a customer KMS key adds cost, production upgrade
  name                 = "clinicflow-api"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the 60 most recent entries (3 per multi-arch push, so about 20 pushes)"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 60
      }
      action = { type = "expire" }
    }]
  })
}
