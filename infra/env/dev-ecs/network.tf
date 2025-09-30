module "network" {
  source = "./modules/vpc"

  aws_region        = var.aws_region
  name              = local.name
  tags              = local.tags
  vpc_id            = var.vpc_id
  public_subnet_ids = var.public_subnet_ids
  allow_https       = var.acm_certificate_arn != ""
}

locals {
  effective_vpc_id = module.network.vpc_id
  private_subnets  = module.network.private_subnet_ids
  public_subnets   = module.network.public_subnet_ids
  selected_subnets = module.network.selected_public_subnet_ids

  alb_security_group_id  = module.network.alb_security_group_id
  ecs_security_group_id  = module.network.ecs_security_group_id
  vpce_security_group_id = module.network.vpce_security_group_id
}
