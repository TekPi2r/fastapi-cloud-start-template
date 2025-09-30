resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = var.tags
}

data "aws_iam_policy_document" "assume_role" {
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

    dynamic "condition" {
      for_each = length(var.allowed_subjects) > 0 ? [1] : []
      content {
        test     = "StringLike"
        variable = "token.actions.githubusercontent.com:sub"
        values   = var.allowed_subjects
      }
    }
  }

  dynamic "statement" {
    for_each = toset(var.trusted_role_arns)
    content {
      sid     = "TrustedRole-${replace(each.value, ":", "-")}"
      actions = ["sts:AssumeRole"]
      effect  = "Allow"
      principals {
        type        = "AWS"
        identifiers = [each.value]
      }
    }
  }
}
