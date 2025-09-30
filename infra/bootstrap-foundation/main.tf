# Resource wiring is split across dedicated files:
# - locals.tf        common naming and tags
# - oidc.tf          GitHub OIDC provider and trust policy
# - ecr.tf           Shared ECR repository for application images
# - iam_build.tf     CI build role with scoped ECR permissions
# - iam_deploy.tf    CD deploy role with least-privilege policy
