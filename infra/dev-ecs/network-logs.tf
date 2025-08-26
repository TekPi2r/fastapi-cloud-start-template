resource "aws_s3_bucket" "alb_logs" { #checkov:skip=CKV_AWS_18 "Ce bucket est déjà un sink de logs ALB" #tfsec:ignore:aws-s3-enable-bucket-logging exp:2025-10-31
  # Ce bucket est un sink de logs ALB ; chaîner des logs sur un bucket de logs n’a pas de valeur.
  bucket        = "${var.name_prefix}-${var.environment}-alb-logs"
  force_destroy = true
  tags          = local.tags
}

# Bloquer tout public access
resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Ownership (requis pour bonnes pratiques modernes)
resource "aws_s3_bucket_ownership_controls" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

# Versioning (check “enable-versioning”)
resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  versioning_configuration { status = "Enabled" }
}

# SSE (SSE-S3 suffit ici ; éviter SSE-KMS qui complique la livraison)
# tfsec se plaint d'absence de CMK → on justifie l'exception :
#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Deny non-TLS
data "aws_iam_policy_document" "alb_logs_bucket_policy" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type = "*"
      identifiers = ["*"]
    }
    resources = [
      aws_s3_bucket.alb_logs.arn,
      "${aws_s3_bucket.alb_logs.arn}/*"
    ]
    condition {
      test = "Bool"
      variable = "aws:SecureTransport"
      values = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs_bucket_policy.json
}
