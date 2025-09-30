locals {
  name = "${var.name_prefix}-${var.environment}"

  log_group_name = (
    var.log_group_name != "" ? var.log_group_name : "/${var.name_prefix}/${var.environment}"
  )

  tags = {
    Name        = var.name_prefix
    Project     = var.name_prefix
    ManagedBy   = "Terraform"
    Environment = var.environment
  }

  kms_account_root        = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
  kms_key_arn_wildcard    = "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
  kms_alb_logs_alias_name = "alias/${local.name}-alb-logs"
}
