output "role_name" {
  value       = aws_iam_role.this.name
  description = "Name of the IAM role created for deployments"
}

output "role_arn" {
  value       = aws_iam_role.this.arn
  description = "ARN of the IAM role created for deployments"
}

output "policy_arn" {
  value       = aws_iam_policy.this.arn
  description = "ARN of the least privilege IAM policy attached to the deploy role"
}
