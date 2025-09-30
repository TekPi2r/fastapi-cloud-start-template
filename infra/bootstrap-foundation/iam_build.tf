module "iam_build" {
  source = "./modules/iam-build"

  role_name          = "${local.name}-build"
  assume_role_policy = module.github_oidc.assume_role_policy
  repo_arn           = module.ecr_dev.repo_arn
  tags               = merge(local.tags, { Name = "${local.name}-build" })
}
