variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "eu-west-3"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for names and tags"
  default     = "fastapi"
}

variable "environment" {
  type        = string
  description = "Environment tag used for scoping conditions"
  default     = "dev"
}

variable "github_owner" {
  type        = string
  description = "GitHub org/user that owns the repository"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (without owner)"
}

variable "allowed_branches" {
  type        = list(string)
  description = "Branches allowed to assume the CI role through OIDC"
  default     = ["main"]
}

variable "ecr_repo_name" {
  type        = string
  description = "ECR repository used by the dev stack"
  default     = "fastapi-dev"
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch Logs group name used by the dev stack"
  default     = "/fastapi/dev"
}

variable "trusted_role_arns" {
  type        = list(string)
  description = "Optional AWS IAM role ARNs allowed to assume the CI role (break-glass or engineering shared)"
  default     = []
}
