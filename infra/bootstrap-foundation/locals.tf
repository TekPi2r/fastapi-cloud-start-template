data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  partition   = data.aws_partition.current.partition
  environment = var.environment
  name        = "${var.name_prefix}-${local.environment}"

  ecr_repo_name  = "${local.name}-ecr"
  log_group_name = "/${var.name_prefix}/${var.environment}"

  tags = {
    Project     = var.name_prefix
    ManagedBy   = "Terraform"
    Environment = local.environment
  }

  github_branch_subjects = [for branch in var.allowed_branches : "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${branch}"]
  github_allowed_subjects = concat(local.github_branch_subjects, [
    "repo:${var.github_owner}/${var.github_repo}:environment:${var.environment}"
  ])

  ecs_task_exec_role_arn    = "arn:aws:iam::${local.account_id}:role/${local.name}-ecs-task-exec"
  ecs_task_runtime_role_arn = "arn:aws:iam::${local.account_id}:role/${local.name}-ecs-task"

  tf_state_bucket_arn  = "arn:aws:s3:::${var.tf_state_bucket}"
  tf_state_objects_arn = "arn:aws:s3:::${var.tf_state_bucket}/dev-ecs/*"
  tf_lock_table_arn    = "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${var.tf_lock_table}"

  log_group_arn                = "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:${local.log_group_name}"
  cloudwatch_alarm_arn_pattern = "arn:aws:cloudwatch:${var.aws_region}:${local.account_id}:alarm:${local.name}-*"
  alb_logs_bucket_arn          = "arn:aws:s3:::${local.name}-alb-logs"
  alb_logs_bucket_objects_arn  = "arn:aws:s3:::${local.name}-alb-logs/*"
}
