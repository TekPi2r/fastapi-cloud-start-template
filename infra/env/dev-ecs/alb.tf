module "alb" {
  source = "./modules/alb"

  name                   = local.name
  tags                   = local.tags
  subnet_ids             = local.selected_subnets
  vpc_id                 = local.effective_vpc_id
  security_group_id      = local.alb_security_group_id
  target_port            = var.container_port
  health_check_path      = "/health"
  acm_certificate_arn    = var.acm_certificate_arn
  log_bucket_name        = "${var.name_prefix}-${var.environment}-alb-logs"
  log_bucket_kms_key_arn = aws_kms_key.alb_logs.arn
}
