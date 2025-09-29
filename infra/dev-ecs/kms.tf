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
