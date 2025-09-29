#tfsec:ignore:aws-ecr-enforce-immutable-repository
# Justification: env de démo; retag contrôlé par CI. Passage à IMMUTABLE quand tags = SHA.
resource "aws_ecr_repository" "api" {
  name                 = "${local.name}-ecr"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  image_scanning_configuration { scan_on_push = true }
  force_delete = true
  tags         = local.tags
}

resource "aws_ecr_lifecycle_policy" "keep_curated" {
  repository = aws_ecr_repository.api.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images, keep last 2"
        selection    = { tagStatus = "untagged", countType = "imageCountMoreThan", countNumber = 2 }
        action       = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 any-tag"
        selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
        action       = { type = "expire" }
      }
    ]
  })
}

data "aws_iam_policy_document" "kms_ecr" {
  statement {
    sid    = "AllowAccountAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [local.kms_account_root]
    }

    actions = [
      "kms:CancelKeyDeletion",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:DescribeKey",
      "kms:DisableKey",
      "kms:DisableKeyRotation",
      "kms:EnableKey",
      "kms:EnableKeyRotation",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListAliases",
      "kms:ListGrants",
      "kms:ListKeyPolicies",
      "kms:ListResourceTags",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:UpdateAlias"
    ]

    resources = [local.kms_key_arn_wildcard]

    condition {
      test     = "ForAnyValue:StringLike"
      variable = "kms:ResourceAliases"
      values   = [local.kms_ecr_alias_name]
    }
  }

  statement {
    sid    = "AllowECRUse"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecr.amazonaws.com"]
    }

    actions = [
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*"
    ]

    resources = [local.kms_key_arn_wildcard]

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = [format("ecr.%s.%s", var.aws_region, data.aws_partition.current.dns_suffix)]
    }

    condition {
      test     = "ForAnyValue:StringLike"
      variable = "kms:ResourceAliases"
      values   = [local.kms_ecr_alias_name]
    }
  }
}

resource "aws_kms_key" "ecr" {
  description         = "KMS key for ECR"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms_ecr.json
  tags                = local.tags
}

resource "aws_kms_alias" "ecr" {
  name          = local.kms_ecr_alias_name
  target_key_id = aws_kms_key.ecr.key_id
}
