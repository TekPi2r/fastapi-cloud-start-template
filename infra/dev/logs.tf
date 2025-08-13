resource "aws_cloudwatch_log_group" "api" {
  name              = "/fastapi/dev"
  retention_in_days = 14
  tags              = local.tags
}
