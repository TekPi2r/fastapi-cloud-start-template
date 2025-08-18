data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  allowed_subs = [
    for b in var.allowed_branches :
    "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${b}"
  ]

  ecr_repo_arn                 = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${var.ecr_repo_name}"
  cw_log_group_arn             = "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:${var.log_group_name}"
  iam_role_target_arn          = "arn:aws:iam::${local.account_id}:role/${var.name_prefix}-dev-ec2-role"
  iam_instance_profile_arn     = "arn:aws:iam::${local.account_id}:instance-profile/${var.name_prefix}-dev-ec2-profile"
  iam_policy_prefix_arn        = "arn:aws:iam::${local.account_id}:policy/${var.name_prefix}"
  aws_managed_ssm_core         = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

  common_tags = {
    Name        = "${var.name_prefix}-bootstrap-foundation"
    ManagedBy   = "Terraform"
    Environment = var.environment
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]

  tags = local.common_tags
}

data "aws_iam_policy_document" "ci_trust" {
  statement {
    sid     = "GitHubOIDC"
    effect  = "Allow"
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

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.allowed_subs
    }
  }

  dynamic "statement" {
    for_each = length(var.trusted_role_arns) > 0 ? [1] : []
    content {
      sid     = "EngineeringBreakGlass"
      effect  = "Allow"
      actions = ["sts:AssumeRole"]

      principals {
        type        = "AWS"
        identifiers = var.trusted_role_arns
      }
    }
  }
}

resource "aws_iam_role" "ci" {
  name               = "${var.name_prefix}-ci"
  assume_role_policy = data.aws_iam_policy_document.ci_trust.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "ci_permissions" {
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

  statement {
    sid     = "EcrScopedRepoRW"
    effect  = "Allow"
    actions = [
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:PutLifecyclePolicy",
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:SetRepositoryPolicy",
      "ecr:GetRepositoryPolicy",
      "ecr:BatchDeleteImage"
    ]
    resources = [local.ecr_repo_arn]
  }

  statement {
    sid     = "CloudWatchLogsScoped"
    effect  = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:DescribeLogGroups",
      "logs:TagLogGroup"
    ]
    resources = [local.cw_log_group_arn]
  }

  statement {
    sid     = "IamRuntimeScoped"
    effect  = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:CreatePolicy",
      "iam:DeletePolicy"
    ]
    resources = [
      local.iam_role_target_arn,
      local.iam_instance_profile_arn,
      "${local.iam_policy_prefix_arn}-*"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  statement {
    sid     = "IamAttachOnlyApprovedPolicies"
    effect  = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy"
    ]
    resources = [local.iam_role_target_arn]

    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values   = [
        local.aws_managed_ssm_core,
        "${local.iam_policy_prefix_arn}-*"
      ]
    }
  }

  statement {
    sid     = "Ec2CoreWithTagGuard"
    effect  = "Allow"
    actions = [
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:Describe*"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/ManagedBy"
      values   = ["Terraform"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Environment"
      values   = [var.environment]
    }
  }

  statement {
    sid     = "Ec2SGMutationsOnlyOnTagged"
    effect  = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:DeleteSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/ManagedBy"
      values   = ["Terraform"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = [var.environment]
    }
  }
}

resource "aws_iam_policy" "ci" {
  name        = "${var.name_prefix}-ci-min"
  description = "Least-privilege policy for GitHub Actions to apply infra/dev"
  policy      = data.aws_iam_policy_document.ci_permissions.json
  tags        = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ci_attach" {
  role       = aws_iam_role.ci.name
  policy_arn = aws_iam_policy.ci.arn
}
