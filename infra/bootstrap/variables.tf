variable "aws_region" {
  description = "AWS region to use"
  type        = string
  default     = "eu-west-3"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "bootstrap"
}

variable "bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform state (e.g., tfstate-yourhandle-euw3)"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for Terraform state locks"
  type        = string
  default     = "terraform-locks"
}

variable "sse_kms_key_arn" {
  description = "Optional KMS key ARN for S3 SSE (leave empty to use AES256)"
  type        = string
  default     = ""
}
