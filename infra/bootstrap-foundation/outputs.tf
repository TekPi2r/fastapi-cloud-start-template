output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "ci_role_arn" {
  description = "ARN of the GitHub Actions CI role"
  value       = aws_iam_role.ci.arn
}
