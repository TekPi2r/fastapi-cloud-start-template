data "aws_iam_policy_document" "build_min" {
  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "EcrPushScoped"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [var.repo_arn]
  }

  statement {
    sid    = "EcrReadScoped"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = [var.repo_arn]
  }

  statement {
    sid       = "EcrDescribeRepo"
    effect    = "Allow"
    actions   = ["ecr:DescribeRepositories"]
    resources = [var.repo_arn]
  }
}

resource "aws_iam_policy" "this" {
  name        = "${var.role_name}-min"
  description = "Least privilege IAM policy for build pipeline"
  policy      = data.aws_iam_policy_document.build_min.json
  tags        = var.tags
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = var.assume_role_policy
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
