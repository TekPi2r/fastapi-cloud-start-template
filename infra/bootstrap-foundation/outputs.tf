output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = module.github_oidc.oidc_provider_arn
}

output "build_role_arn" {
  description = "Role to assume in GitHub Actions for the Build pipeline"
  value       = module.iam_build.role_arn
}

output "deploy_role_arn" {
  description = "Role to assume in GitHub Actions for the Deploy pipeline"
  value       = module.iam_deploy.role_arn
}

output "build_policy_arn" {
  description = "IAM policy attached to the build role"
  value       = module.iam_build.policy_arn
}

output "deploy_policy_arn" {
  description = "IAM policy attached to the deploy role"
  value       = module.iam_deploy.policy_arn
}

output "ecr_repo_name_dev" {
  description = "Name of the dev ECR repository"
  value       = module.ecr_dev.repo_name
}

output "ecr_repo_arn_dev" {
  description = "ARN of the dev ECR repository"
  value       = module.ecr_dev.repo_arn
}

output "ecr_repo_url_dev" {
  description = "Repository URL of the dev ECR repository"
  value       = module.ecr_dev.repository_url
}
