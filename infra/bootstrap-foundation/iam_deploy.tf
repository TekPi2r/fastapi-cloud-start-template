data "aws_kms_alias" "tfstate" {
  name = "alias/${var.name_prefix}-tfstate"
}

data "aws_kms_alias" "tf_locks" {
  name = "alias/${var.name_prefix}-tf-locks"
}

locals {
  tfstate_kms_key_arn  = "arn:aws:kms:${var.aws_region}:${local.account_id}:key/${data.aws_kms_alias.tfstate.target_key_id}"
  tf_locks_kms_key_arn = "arn:aws:kms:${var.aws_region}:${local.account_id}:key/${data.aws_kms_alias.tf_locks.target_key_id}"
}

module "iam_deploy" {
  source = "./modules/iam-deploy"

  role_name          = "${local.name}-deploy"
  assume_role_policy = module.github_oidc.assume_role_policy
  tags               = merge(local.tags, { Name = "${local.name}-deploy" })

  aws_region   = var.aws_region
  account_id   = local.account_id
  ecr_repo_arn = module.ecr_dev.repo_arn

  tf_state_bucket_arn  = local.tf_state_bucket_arn
  tf_state_objects_arn = local.tf_state_objects_arn
  tf_lock_table_arn    = local.tf_lock_table_arn

  ecs_task_exec_role_arn    = local.ecs_task_exec_role_arn
  ecs_task_runtime_role_arn = local.ecs_task_runtime_role_arn

  kms_state_key_arn = local.tfstate_kms_key_arn
  kms_locks_key_arn = local.tf_locks_kms_key_arn

  log_group_arn                = local.log_group_arn
  cloudwatch_alarm_arn_pattern = local.cloudwatch_alarm_arn_pattern
}
