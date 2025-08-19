resource "aws_ecr_repository" "api" {
  name                 = "${local.name}-ecr" # <- fastapi-dev-ecr
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
  force_delete         = true   # << supprime aussi si des images restent
  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "keep_last_10" {
  repository = aws_ecr_repository.api.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
