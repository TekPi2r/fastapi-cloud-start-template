output "ecr_repo_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.api.repository_url
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.api.name
}

output "security_group_id" {
  value = aws_security_group.api.id
}

output "instance_id" {
  value = aws_instance.api.id
}

output "instance_public_ip" {
  value = aws_instance.api.public_ip
}
