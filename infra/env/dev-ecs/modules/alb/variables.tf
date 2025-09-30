variable "name" {
  description = "Base name (e.g. fastapi-dev)"
  type        = string
}

variable "tags" {
  description = "Tags to propagate"
  type        = map(string)
}

variable "subnet_ids" {
  description = "Subnets where the ALB will be deployed"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID attached to the ALB"
  type        = string
}

variable "target_port" {
  description = "Port exposed by the ECS service"
  type        = number
  default     = 8000
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}

variable "acm_certificate_arn" {
  description = "Optional ACM certificate ARN to enable HTTPS listener"
  type        = string
  default     = ""
}

variable "log_bucket_name" {
  description = "Name of the S3 bucket storing ALB access logs"
  type        = string
}

variable "log_bucket_kms_key_arn" {
  description = "ARN of the KMS key encrypting ALB access logs"
  type        = string
}
