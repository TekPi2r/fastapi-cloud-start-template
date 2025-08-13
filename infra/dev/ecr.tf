resource "aws_ecr_repository" "api" {
  name = var.ecr_repo_name

  image_scanning_configuration { scan_on_push = true }
  image_tag_mutability = "MUTABLE"

  # AES256 par défaut (passe à KMS si besoin compliance)
  encryption_configuration { encryption_type = "AES256" }

  tags = local.tags
}

# Ne garde que les 10 dernières images pour éviter l’accumulation
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1,
      description  = "Keep last 10 images",
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 },
      action       = { type = "expire" }
    }]
  })
}
