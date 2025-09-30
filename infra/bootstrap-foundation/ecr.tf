module "ecr_dev" {
  source = "./modules/ecr"

  name = local.ecr_repo_name
  tags = merge(local.tags, { Name = local.ecr_repo_name })
}
