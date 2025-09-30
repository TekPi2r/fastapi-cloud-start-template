output "repo_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.this.name
}

output "repo_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.this.arn
}

output "repository_url" {
  description = "Repository URL (account.dkr.ecr.region.amazonaws.com/name)"
  value       = aws_ecr_repository.this.repository_url
}
