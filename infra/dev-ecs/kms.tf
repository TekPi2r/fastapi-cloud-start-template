resource "aws_kms_key" "logs" {
  description         = "KMS key for CloudWatch logs"
  enable_key_rotation = true

  policy = <<POLICY
  {
    "Version": "2025-08-26",
    "Id": "default",
    "Statement": [
      {
        "Sid": "DefaultAllow",
        "Effect": "Allow",
        "Principal": {
        },
        "Action": "kms:*",
        "Resource": "*"
      }
    ]
  }
POLICY

  tags = local.tags
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${local.name}-logs"
  target_key_id = aws_kms_key.logs.key_id
}


data "aws_iam_policy_document" "kms_alb_logs" {
  statement {
    sid    = "AllowAccountAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
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
}

resource "aws_kms_key" "alb_logs" {
  description         = "KMS key for ALB access logs bucket"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms_alb_logs.json
  tags                = local.tags
}

resource "aws_kms_alias" "alb_logs" {
  name          = "alias/${local.name}-alb-logs"
  target_key_id = aws_kms_key.alb_logs.key_id
}
