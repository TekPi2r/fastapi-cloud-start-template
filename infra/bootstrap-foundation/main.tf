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

  tf_state_bucket_arn  = "arn:aws:s3:::${var.tf_state_bucket}"
  # state file lives under the dev-ecs prefix
  tf_state_objects_arn = "arn:aws:s3:::${var.tf_state_bucket}/dev-ecs/*"
  tf_lock_table_arn    = "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${var.tf_lock_table}"


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

  # S3 backend: bucket-level ops
  statement {
    sid     = "S3TfStateBucket"
    effect  = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [local.tf_state_bucket_arn]
  }

  # S3 backend: object-level ops on the dev-ecs prefix
  statement {
    sid     = "S3TfStateObjectRW"
    effect  = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [local.tf_state_objects_arn]
  }

  # DynamoDB state lock table
  statement {
    sid     = "DdbTfLockRW"
    effect  = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem"
    ]
    resources = [local.tf_lock_table_arn]
  }

  # --- AJOUTS: lectures nécessaires au "terraform plan" ---

  # EC2 describe pour data.aws_vpc / data.aws_subnets / SG
  statement {
    sid     = "Ec2ReadDescribe"
    effect  = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups"
    ]
    resources = ["*"]
  }

  # ALB/Target Groups describe pour rafraîchir aws_lb / aws_lb_target_group / listener
  statement {
    sid     = "ElbReadDescribe"
    effect  = "Allow"
    actions = [
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags"       # <- add this
    ]
    resources = ["*"]
  }

  # CloudWatch Logs pour aws_cloudwatch_log_group
  statement {
    sid     = "LogsReadDescribe"
    effect  = "Allow"
    actions = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  # ECR describe du repo (le plan lit le repo existant)
  statement {
    sid     = "EcrRepoRead"
    effect  = "Allow"
    actions = ["ecr:DescribeRepositories"]
    resources = ["*"]
  }

  # Lecture ciblée des rôles ECS (utile quand le provider vérifie les rôles référencés)
  statement {
    sid     = "IamReadRole"
    effect  = "Allow"
    actions = ["iam:GetRole"]
    resources = [
      local.ecs_task_exec_role_arn,
      local.ecs_task_runtime_role_arn
    ]
  }

  # IAM: lire les inline/attached policies des rôles ECS
  statement {
    sid     = "IamListRolePolicies"
    effect  = "Allow"
    actions = [
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:GetRolePolicy"
    ]
    resources = [
      local.ecs_task_exec_role_arn,
      local.ecs_task_runtime_role_arn
    ]
  }

  # IAM: lire les policies AWS gérées renvoyées par ListAttachedRolePolicies
  statement {
    sid     = "IamReadAwsManagedPolicies"
    effect  = "Allow"
    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions"
    ]
    resources = ["arn:aws:iam::aws:policy/*"]
  }

  # CloudWatch Logs: lecture des tags du log group
  statement {
    sid     = "LogsListTagsForResource"
    effect  = "Allow"
    actions = ["logs:ListTagsForResource"]
    resources = [local.log_group_arn]
  }

  # EC2: attributs VPC + (optionnel) AZ/account attrs
  statement {
    sid     = "Ec2ReadVpcAttrs"
    effect  = "Allow"
    actions = [
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAvailabilityZones"
    ]
    resources = ["*"]
  }

  # ECR: lecture des tags du repo
  statement {
    sid     = "EcrListTagsForResource"
    effect  = "Allow"
    actions = ["ecr:ListTagsForResource"]
    resources = [local.ecr_repo_arn]
  }

  # ELBv2: lecture des ATTRIBUTES du LB
  statement {
    sid     = "ElbReadAttributesLb"
    effect  = "Allow"
    actions = ["elasticloadbalancing:DescribeLoadBalancerAttributes"]
    resources = ["*"] # les ARNs exacts varient, on reste en read-only global
  }

  # ELBv2: lecture des ATTRIBUTES du Target Group
  statement {
    sid     = "ElbReadAttributesTg"
    effect  = "Allow"
    actions = ["elasticloadbalancing:DescribeTargetGroupAttributes"]
    resources = ["*"]
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
