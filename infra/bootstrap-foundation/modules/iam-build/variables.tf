variable "role_name" {
  description = "Name of the IAM role to create"
  type        = string
}

variable "assume_role_policy" {
  description = "JSON policy document granting access to assume the role"
  type        = string
}

variable "repo_arn" {
  description = "ARN of the ECR repository that the build pipeline pushes to"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources created by this module"
  type        = map(string)
}
