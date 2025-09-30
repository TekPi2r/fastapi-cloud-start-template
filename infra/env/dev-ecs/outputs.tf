output "ecr_repo_url" {
  value       = data.aws_ecr_repository.fastapi_dev.repository_url
  description = "ECR repository URL"
}

output "cluster_name" {
  value       = module.ecs.cluster_name
  description = "ECS cluster name"
}

output "service_name" {
  value       = module.ecs.service_name
  description = "ECS service name"
}

output "alb_dns_name" {
  value       = module.alb.lb_dns_name
  description = "ALB public DNS"
}

output "log_group_name" {
  value       = aws_cloudwatch_log_group.api.name
  description = "CloudWatch Log Group"
}

output "task_role_arn" {
  description = "IAM role assumed by the ECS task (app runtime)"
  value       = aws_iam_role.task_runtime.arn
}

output "exec_role_arn" {
  description = "IAM role assumed by the ECS task (execution)"
  value       = aws_iam_role.task_execution.arn
}
