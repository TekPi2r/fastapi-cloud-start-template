variable "name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources in the module"
  type        = map(string)
}

variable "encryption_type" {
  description = "ECR encryption type (KMS or AES256). Defaults to KMS managed by AWS."
  type        = string
  default     = "KMS"
}

variable "scan_on_push" {
  description = "Either enable or disable image scanning on push"
  type        = bool
  default     = true
}

variable "untagged_retention_days" {
  description = "How many days to retain untagged images"
  type        = number
  default     = 14
}
