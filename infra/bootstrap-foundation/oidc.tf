module "github_oidc" {
  source = "./modules/oidc-github"

  allowed_subjects  = local.github_allowed_subjects
  trusted_role_arns = var.trusted_role_arns
  tags              = merge(local.tags, { Name = "${local.name}-github-oidc" })
}
