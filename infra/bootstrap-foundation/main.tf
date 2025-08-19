# bootstrap-foundation/main.tf

data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  environment   = var.environment
  name          = "${var.name_prefix}-${local.environment}"   # fastapi-dev
  ecr_repo_name = "${local.name}-ecr"                         # fastapi-dev-ecr
  log_group_name = "/${var.name_prefix}/${var.environment}"

  # e.g. ["repo:TekPi2r/fastapi-cloud-start-template:ref:refs/heads/main"]
  github_subs = [for b in var.allowed_branches : "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${b}"]

  ecr_repo_arn  = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${local.ecr_repo_name}"
  log_group_arn = "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:${local.log_group_name}"

  # Task/Execution role names used by ECS tasks (created in infra/dev-ecs)
  ecs_task_exec_role_arn = "arn:aws:iam::${local.account_id}:role/${local.name}-ecs-task-exec"
  # If you later add a *task runtime* role, prefer naming: "${var.name_prefix}-${local.environment}-ecs-task"
  ecs_task_runtime_role_arn = "arn:aws:iam::${local.account_id}:role/${local.name}-ecs-task"

  tags = {
    Name        = var.name_prefix       # <- always "fastapi"
    ManagedBy   = "Terraform"
    Environment = local.environment     # "dev"
  }
}

# --- GitHub OIDC provider (one per account) ---
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name        = "${local.name}-bootstrap-foundation"
    ManagedBy   = "Terraform"
    Environment = local.environment
  }
}

# --- Trust policy shared by build/deploy roles ---
data "aws_iam_policy_document" "oidc_trust" {
  statement {
    sid     = "GitHubOIDC"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Autoriser soit un run sur la branche main, soit un run taggé sur l'environnement dev
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = concat(
        tolist(local.github_subs),  # <- flatten/normalize the tuple
        ["repo:${var.github_owner}/${var.github_repo}:environment:${var.environment}"]
      )
    }
  }
}

# =====================
# Role: fastapi-*-build
# =====================

# Least-privilege policy for Build pipeline: push images to one ECR repo
data "aws_iam_policy_document" "build_min" {
  # ECR auth + describe (global)
  statement {
    sid     = "EcrAuth"
    effect  = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:BatchGetImage"
    ]
    resources = ["*"]
  }

  # Push to the scoped repository only
  statement {
    sid     = "EcrPushScoped"
    effect  = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
    resources = [local.ecr_repo_arn]
  }
}

resource "aws_iam_policy" "fastapi_build_min" {
  name        = "${local.name}-build-min"
  description = "Least-privilege for GitHub Actions build (ECR push to ${local.ecr_repo_name})"
  policy      = data.aws_iam_policy_document.build_min.json

  tags = {
    Name        = "${local.name}-build-min"
    ManagedBy   = "Terraform"
    Environment = local.environment
  }
}

resource "aws_iam_role" "fastapi_build" {
  name               = "${local.name}-build"
  assume_role_policy = data.aws_iam_policy_document.oidc_trust.json

  tags = {
    Name        = "${local.name}-build"
    ManagedBy   = "Terraform"
    Environment = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "fastapi_build_attach" {
  role       = aws_iam_role.fastapi_build.name
  policy_arn = aws_iam_policy.fastapi_build_min.arn
}

# ======================
# Role: fastapi-*-deploy
# ======================

# Least-privilege policy for Deploy pipeline: register task def + update service
data "aws_iam_policy_document" "deploy_min" {
  # ECS read + mutate only what we need
  statement {
    sid     = "EcsCore"
    effect  = "Allow"
    actions = [
      "ecs:Describe*",
      "ecs:List*",
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:UpdateService"
    ]
    resources = ["*"]
  }

  # Allow passing ONLY our ECS task roles to ECS tasks
  statement {
    sid     = "IamPassOnlyEcsTaskRoles"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      local.ecs_task_exec_role_arn,
      local.ecs_task_runtime_role_arn
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  # ECR read of our repo (to resolve image digest during deployment if needed)
  statement {
    sid     = "EcrReadRepo"
    effect  = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = [local.ecr_repo_arn]
  }
}

resource "aws_iam_policy" "fastapi_deploy_min" {
  name        = "${local.name}-deploy-min"
  description = "Least-privilege for GitHub Actions deploy (ECS update + ECR read)"
  policy      = data.aws_iam_policy_document.deploy_min.json

  tags = {
    Name        = "${local.name}-deploy-min"
    ManagedBy   = "Terraform"
    Environment = local.environment
  }
}

resource "aws_iam_role" "fastapi_deploy" {
  name               = "${local.name}-deploy"
  assume_role_policy = data.aws_iam_policy_document.oidc_trust.json

  tags = {
    Name        = "${local.name}-deploy"
    ManagedBy   = "Terraform"
    Environment = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "fastapi_deploy_attach" {
  role       = aws_iam_role.fastapi_deploy.name
  policy_arn = aws_iam_policy.fastapi_deploy_min.arn
}
