# ==============================
# variables.tf — dev-ecs
# Centralised variables for ECS/ECR stack
# ==============================

variable "aws_region" {
  description = "AWS region (e.g., eu-west-3). If omitted, the AWS provider/env will be used."
  type        = string
}

# Project name WITHOUT the environment. Used to build resource names/tags via locals.
# Example: name_prefix = "fastapi" -> resources like fastapi-dev-*
variable "name_prefix" {
  description = "Project name (no env)."
  type        = string
  default     = "fastapi"
}

# Short environment label used in names/tags (e.g., dev, staging, prod)
variable "environment" {
  description = "Environment tag used for scoping conditions and naming."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "environment must contain only lowercase letters, digits, or hyphens."
  }
}

# Docker image tag to deploy (e.g., from CI). Example: 'dev', 'main', 'sha-abcdef'
variable "image_tag" {
  description = "Docker image tag to deploy."
  type        = string
  default     = "dev"
}

# ECS service desired tasks
variable "desired_count" {
  description = "Number of desired tasks for the ECS service."
  type        = number
  default     = 1
}

# Fargate task sizing
variable "task_cpu" {
  description = "Fargate task CPU units (valid: 256, 512, 1024, 2048, 4096)."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory (MB). Common pairs: 256/512, 512/1024, 1024/2048, 2048/4096, 4096/8192"
  type        = number
  default     = 512
}

# Networking
variable "vpc_id" {
  description = "VPC ID to use. Empty = use the default VPC."
  type        = string
  default     = ""
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB/ECS. Empty = take first two public subnets from the VPC."
  type        = list(string)
  default     = []
}

# TLS/HTTPS
variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Empty = expose only HTTP listener."
  type        = string
  default     = ""
}

# Logs
# Leave empty to auto-compute '/<name_prefix>/<environment>' via locals (recommended).
variable "log_group_name" {
  description = "CloudWatch Logs group name. If empty, defaults to '/<name_prefix>/<environment>'."
  type        = string
  default     = ""
}

# App network
variable "container_port" {
  description = "Container/listener port exposed by the app."
  type        = number
  default     = 8000
}

# ALB Settings
variable "min_capacity" {
  description = "Minimum CPU capacity used by the app."
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maxium CPU capacity that can be used by the app."
  type        = number
  default     = 3
}

variable "target_cpu" {
  description = "Target CPU to be used by the app."
  type        = number
  default     = 70
}