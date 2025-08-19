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

variable "trusted_role_arns" {
  type        = list(string)
  description = "Optional AWS IAM role ARNs allowed to assume the CI role (break-glass or engineering shared)"
  default     = []
}

variable "tf_state_bucket" {
  description = "S3 bucket where TF state for dev-ecs is stored"
  type        = string
}

variable "tf_lock_table" {
  description = "DynamoDB table used for TF state locking"
  type        = string
}

