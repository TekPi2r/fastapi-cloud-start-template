variable "name" {
  description = "Base name for ECS resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "image" {
  description = "Container image (repository url + tag)"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "desired_count" {
  description = "Desired task count"
  type        = number
}

variable "task_cpu" {
  description = "CPU units for the task"
  type        = number
}

variable "task_memory" {
  description = "Memory (MiB) for the task"
  type        = number
}

variable "subnet_ids" {
  description = "Subnets for the ECS service"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to the ECS service ENI"
  type        = list(string)
}

variable "target_group_arn" {
  description = "Target group ARN for the load balancer"
  type        = string
}

variable "execution_role_arn" {
  description = "IAM role ARN for ECS execution"
  type        = string
}

variable "task_role_arn" {
  description = "IAM role ARN for ECS task runtime"
  type        = string
}

variable "environment" {
  description = "Environment variables passed to the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "container_name" {
  description = "Logical container name"
  type        = string
  default     = "api"
}

variable "container_port" {
  description = "Container port exposed"
  type        = number
  default     = 8000
}

variable "platform_version" {
  description = "Fargate platform version"
  type        = string
  default     = "LATEST"
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP to tasks"
  type        = bool
  default     = false
}

variable "enable_execute_command" {
  description = "Enable ECS Exec"
  type        = bool
  default     = true
}
