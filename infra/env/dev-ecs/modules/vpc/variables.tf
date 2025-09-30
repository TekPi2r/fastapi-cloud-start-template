variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "name" {
  description = "Base name for resources (e.g. fastapi-dev)"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
}

variable "vpc_id" {
  description = "Optional VPC ID. If empty the default VPC is used."
  type        = string
  default     = ""
}

variable "public_subnet_ids" {
  description = "Optional explicit public subnet IDs for the load balancer"
  type        = list(string)
  default     = []
}

variable "allow_https" {
  description = "Whether to open port 443 on the ALB security group"
  type        = bool
  default     = false
}
