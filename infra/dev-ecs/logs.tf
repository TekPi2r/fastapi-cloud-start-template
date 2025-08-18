resource "aws_cloudwatch_log_group" "api" {
  name              = var.log_group_name
  retention_in_days = 14

  tags = {
    Name        = var.name_prefix
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}
