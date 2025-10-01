data "aws_iam_policy_document" "kms_logs" {
  statement {
    sid    = "AccountRoot"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [local.kms_account_root]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [format("logs.%s.%s", var.aws_region, data.aws_partition.current.dns_suffix)]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = [
        "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_name}",
        "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_name}:*"
      ]
    }
  }
}

resource "aws_kms_key" "logs" {
  description         = "KMS key for CloudWatch logs"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms_logs.json
  tags                = local.tags
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${local.name}-logs"
  target_key_id = aws_kms_key.logs.key_id
}


data "aws_iam_policy_document" "kms_alb_logs" {
  statement {
    sid    = "AccountRoot"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [local.kms_account_root]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowS3AccessLogs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = [
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = [format("s3.%s.%s", var.aws_region, data.aws_partition.current.dns_suffix)]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = ["arn:${data.aws_partition.current.partition}:s3:::${var.name_prefix}-${var.environment}-alb-logs/*"]
    }
  }

  statement {
    sid    = "AllowELBLogDeliveryUseOfKey"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [
        "logdelivery.elb.amazonaws.com",
        "delivery.logs.amazonaws.com",
        "elasticloadbalancing.amazonaws.com"
      ]
    }

    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:ReEncrypt*",
      "kms:DescribeKey"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "alb_logs" {
  description         = "KMS key for ALB access logs bucket"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms_alb_logs.json
  tags                = local.tags
}

resource "aws_kms_alias" "alb_logs" {
  name          = local.kms_alb_logs_alias_name
  target_key_id = aws_kms_key.alb_logs.key_id
}
