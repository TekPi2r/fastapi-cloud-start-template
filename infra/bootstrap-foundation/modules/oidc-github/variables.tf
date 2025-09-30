variable "allowed_subjects" {
  description = "List of GitHub Actions subject claims allowed to assume the role"
  type        = list(string)
}

variable "trusted_role_arns" {
  description = "Optional list of IAM role ARNs allowed to assume the generated roles"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to the OIDC provider"
  type        = map(string)
}
