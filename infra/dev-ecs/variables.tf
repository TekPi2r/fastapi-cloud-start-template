variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "name_prefix" {
  description = "Name prefix for resources (e.g., fastapi-dev)"
  type        = string
}

variable "ecr_repo_name" {
  description = "ECR repository name"
  type        = string
  default     = "fastapi-dev"
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "dev"
}

variable "desired_count" {
  description = "ECS service desired tasks"
  type        = number
  default     = 1
}

variable "task_cpu" {
  description = "Fargate task CPU (e.g., 256, 512)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory (MB)"
  type        = number
  default     = 512
}

variable "vpc_id" {
  description = "VPC id to use (empty = default VPC)"
  type        = string
  default     = ""
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB/ECS (empty = first two of VPC)"
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS (empty = HTTP only)"
  type        = string
  default     = ""
}

variable "log_group_name" {
  description = "CloudWatch Logs group name"
  type        = string
  default     = "/fastapi/dev"
}
