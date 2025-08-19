output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "build_role_arn" {
  description = "Role to assume in GitHub Actions for the Build pipeline"
  value       = aws_iam_role.fastapi_build.arn
}

output "deploy_role_arn" {
  description = "Role to assume in GitHub Actions for the Deploy pipeline"
  value       = aws_iam_role.fastapi_deploy.arn
}
