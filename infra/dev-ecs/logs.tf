resource "aws_cloudwatch_log_group" "api" {
  name              = local.log_group_name
  retention_in_days = 14

  tags = local.tags
}
