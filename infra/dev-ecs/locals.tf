locals {
  # Base
  name = "${var.name_prefix}-${var.environment}" # ex: fastapi-dev

  # Logs
  log_group_name = (
    var.log_group_name != "" ? var.log_group_name : "/${var.name_prefix}/${var.environment}"
  )

  # Tags communs
  tags = {
    Name        = var.name_prefix # ==> "fastapi"
    ManagedBy   = "Terraform"
    Environment = var.environment # ==> "dev"
  }
}
