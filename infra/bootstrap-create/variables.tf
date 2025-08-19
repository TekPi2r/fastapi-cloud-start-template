variable "aws_region" {
  type        = string
  description = "AWS region to deploy bootstrap state resources"
  default     = "eu-west-3"
}

variable "bucket_name" {
  type        = string
  description = "S3 bucket name for Terraform state (must be globally unique)"
}

variable "dynamodb_table_name" {
  type        = string
  description = "DynamoDB table name for Terraform state locks"
  default     = "terraform-locks"
}

variable "name_prefix" {
  type        = string
  description = "Tags prefix for naming"
  default     = "fastapi"
}

variable "environment" {
  type        = string
  description = "Environment tag"
  default     = "bootstrap"
}
