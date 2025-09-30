output "role_name" {
  value       = aws_iam_role.this.name
  description = "Name of the IAM role created for deployments"
}

output "role_arn" {
  value       = aws_iam_role.this.arn
  description = "ARN of the IAM role created for deployments"
}

output "core_policy_arn" {
  value       = aws_iam_policy.core.arn
  description = "ARN of the read/back-end policy attached to the deploy role"
}

output "manage_policy_arn" {
  value       = aws_iam_policy.manage.arn
  description = "ARN of the mutable permissions policy attached to the deploy role"
}
