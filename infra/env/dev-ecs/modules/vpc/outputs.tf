output "vpc_id" {
  description = "Effective VPC ID used for resources"
  value       = local.effective_vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = local.private_subnets
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = local.public_subnets
}

output "selected_public_subnet_ids" {
  description = "Subset of public subnets used by the ALB"
  value       = local.selected_public_subnets
}

output "alb_security_group_id" {
  description = "Security group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs_tasks.id
}

output "vpce_security_group_id" {
  description = "Security group ID attached to the VPC endpoints"
  value       = aws_security_group.vpce.id
}

output "vpc_endpoint_ids" {
  description = "Map of VPC endpoint IDs keyed by service"
  value       = { for k, v in aws_vpc_endpoint.interfaces : k => v.id }
}
