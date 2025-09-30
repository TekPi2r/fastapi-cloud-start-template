output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "assume_role_policy" {
  description = "JSON assume role policy document allowing GitHub OIDC subjects and optional trusted roles"
  value       = data.aws_iam_policy_document.assume_role.json
}
