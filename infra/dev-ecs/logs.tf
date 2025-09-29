resource "aws_cloudwatch_log_group" "api" {
  name              = local.log_group_name
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs.arn
  tags              = local.tags
}
