locals {
  tags = {
    Name        = "${var.name_prefix}-tfstate"
    ManagedBy   = "Terraform"
    Environment = var.environment
  }
}

data "aws_caller_identity" "current" {}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "tf_state" { #tfsec:ignore:aws-s3-enable-bucket-logging exp:2025-10-31
  # Server access logging nécessite des ACLs, en conflit avec BucketOwnerEnforced.
  # Couverture via CloudTrail Data Events si requis.
  #checkov:skip=CKV_AWS_18: "Ensure the S3 bucket has access logging enabled"
  #checkov:skip=CKV2_AWS_62: "Ensure S3 buckets should have event notifications enabled"
  #checkov:skip=CKV_AWS_144: "Ensure that S3 bucket has cross-region replication enabled"
  bucket        = var.bucket_name
  force_destroy = true # << supprime toutes les versions au destroy

  tags = local.tags
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket owner enforced
resource "aws_s3_bucket_ownership_controls" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Versioning ON
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_kms_key" "tfstate" {
  description         = "KMS for Terraform state bucket"
  enable_key_rotation = true
  tags                = local.tags
}

resource "aws_kms_alias" "tfstate" {
  name          = "alias/${var.name_prefix}-tfstate"
  target_key_id = aws_kms_key.tfstate.key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tfstate.arn
    }
  }
}

# Abort incomplete multipart uploads after 7 days
resource "aws_s3_bucket_lifecycle_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    id     = "abort-incomplete-mpu"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    filter {}
  }

  depends_on = [
    aws_s3_bucket_public_access_block.tf_state,
    aws_s3_bucket_ownership_controls.tf_state,
    aws_s3_bucket_versioning.tf_state,
    aws_s3_bucket_server_side_encryption_configuration.tf_state
  ]
}

# Deny non-TLS access
data "aws_iam_policy_document" "tf_state" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:*"
    ]

    resources = [
      aws_s3_bucket.tf_state.arn,
      "${aws_s3_bucket.tf_state.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  policy = data.aws_iam_policy_document.tf_state.json
}

# --- KMS pour DynamoDB lock table (CMK perso) ---
resource "aws_kms_key" "tf_locks" {
  description         = "${var.name_prefix}-tf-locks"
  enable_key_rotation = true
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Admin du compte
      {
        Sid: "AllowRoot",
        Effect: "Allow",
        Principal: { AWS: "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
        Action: "kms:*",
        Resource: "*"
      },
      # DynamoDB service peut utiliser la clé (contexte: ce compte + ce service)
      {
        Sid: "AllowDynamoDBUseOfTheKey",
        Effect: "Allow",
        Principal: { Service: "dynamodb.amazonaws.com" },
        Action: [
          "kms:Encrypt","kms:Decrypt","kms:ReEncrypt*",
          "kms:GenerateDataKey*","kms:DescribeKey"
        ],
        Resource: "*",
        Condition: {
          StringEquals: {
            "aws:SourceAccount": "${data.aws_caller_identity.current.account_id}"
          },
          StringLike: {
            "kms:ViaService": "dynamodb.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })
  tags = local.tags
}

resource "aws_kms_alias" "tf_locks" {
  name          = "alias/${var.name_prefix}-tf-locks"
  target_key_id = aws_kms_key.tf_locks.id
}

# DynamoDB table for state locks
resource "aws_dynamodb_table" "tf_locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
    kms_key_arn = aws_kms_key.tf_locks.arn
  }
  point_in_time_recovery {
    enabled = true
  }

  tags = local.tags
}
