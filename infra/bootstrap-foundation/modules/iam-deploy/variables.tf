variable "role_name" {
  description = "Name of the IAM role to create"
  type        = string
}

variable "assume_role_policy" {
  description = "JSON policy document that defines who can assume the role"
  type        = string
}

variable "tags" {
  description = "Tags applied to the IAM resources"
  type        = map(string)
}

variable "aws_region" {
  description = "AWS region where resources are hosted"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "ecr_repo_arn" {
  description = "ARN of the ECR repository for the application"
  type        = string
}

variable "tf_state_bucket_arn" {
  description = "ARN of the S3 bucket storing Terraform state"
  type        = string
}

variable "tf_state_objects_arn" {
  description = "ARN of the S3 objects path for Terraform state"
  type        = string
}

variable "tf_lock_table_arn" {
  description = "ARN of the DynamoDB table used for Terraform state locking"
  type        = string
}

variable "ecs_task_exec_role_arn" {
  description = "ARN of the ECS execution role"
  type        = string
}

variable "ecs_task_runtime_role_arn" {
  description = "ARN of the ECS task runtime role"
  type        = string
}

variable "kms_state_key_arn" {
  description = "ARN of the KMS key encrypting Terraform state objects"
  type        = string
}

variable "kms_locks_key_arn" {
  description = "ARN of the KMS key protecting the DynamoDB lock table"
  type        = string
}

variable "log_group_arn" {
  description = "ARN of the CloudWatch log group used by the ECS service"
  type        = string
}

variable "cloudwatch_alarm_arn_pattern" {
  description = "ARN pattern for CloudWatch alarms managed by Terraform"
  type        = string
}
