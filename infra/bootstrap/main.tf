locals {
  tags = {
    Name        = "Terraform State Bucket"
    Environment = "bootstrap"
    ManagedBy   = "Terraform"
  }
}

# --- S3 bucket pour le state ---
resource "aws_s3_bucket" "tf_state" {
  bucket = var.bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration { status = "Enabled" }
}

# Désactive les ACLs et force l’owner (requis provider v5)
resource "aws_s3_bucket_ownership_controls" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

# Bloque tout accès public (ACL/Policy)
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Chiffrement côté serveur (AES256 par défaut, KMS si fourni)
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_kms_key_arn == "" ? "AES256" : "aws:kms"
      kms_master_key_id = var.sse_kms_key_arn == "" ? null : var.sse_kms_key_arn
    }
  }
}

# Bonnes pratiques lifecycle : abort MPU
resource "aws_s3_bucket_lifecycle_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    id     = "abort-incomplete-mpu"
    status = "Enabled"
    # apply to all objects (required by provider v5)
    filter {}
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

# Politique : refuse HTTP et uploads non chiffrés
data "aws_iam_policy_document" "tf_state" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.tf_state.arn, "${aws_s3_bucket.tf_state.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "DenyUnEncryptedObjectUploads"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.tf_state.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = [var.sse_kms_key_arn == "" ? "AES256" : "aws:kms"]
    }
  }
}

resource "aws_s3_bucket_policy" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  policy = data.aws_iam_policy_document.tf_state.json
}

# --- DynamoDB table pour les locks ---
resource "aws_dynamodb_table" "tf_locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.tags
}
