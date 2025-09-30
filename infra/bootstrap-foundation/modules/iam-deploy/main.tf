data "aws_partition" "current" {}

#checkov:skip=CKV_AWS_111: Terraform deploy role needs scoped write permissions for ECS deploy operations
#checkov:skip=CKV_AWS_356: ECS/ELB APIs require wildcard resources for Describe/Register actions
data "aws_iam_policy_document" "deploy_min" {
  statement {
    sid    = "KmsUseTfStateKey"
    effect = "Allow"
    actions = [
      "kms:CreateGrant",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:ReEncrypt*"
    ]
    resources = [var.kms_state_key_arn]
  }

  statement {
    sid    = "KmsUseTfLocksKey"
    effect = "Allow"
    actions = [
      "kms:CreateGrant",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:ReEncrypt*"
    ]
    resources = [var.kms_locks_key_arn]
  }

  statement {
    sid    = "EcsCore"
    effect = "Allow"
    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:ListClusters",
      "ecs:ListServices",
      "ecs:ListTaskDefinitions",
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:UpdateService"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "IamPassOnlyEcsTaskRoles"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      var.ecs_task_exec_role_arn,
      var.ecs_task_runtime_role_arn
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid    = "EcrReadRepo"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = [var.ecr_repo_arn]
  }

  statement {
    sid    = "S3TfStateBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [var.tf_state_bucket_arn]
  }

  statement {
    sid    = "S3TfStateObjectRW"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [var.tf_state_objects_arn]
  }

  statement {
    sid    = "DdbTfLockRW"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem"
    ]
    resources = [var.tf_lock_table_arn]
  }

  statement {
    sid    = "Ec2ReadDescribe"
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ElbReadDescribe"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "LogsReadDescribe"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "EcrRepoReadDescribe"
    effect    = "Allow"
    actions   = ["ecr:DescribeRepositories"]
    resources = ["*"]
  }

  statement {
    sid     = "IamReadRole"
    effect  = "Allow"
    actions = ["iam:GetRole"]
    resources = [
      var.ecs_task_exec_role_arn,
      var.ecs_task_runtime_role_arn
    ]
  }

  statement {
    sid    = "IamListRolePolicies"
    effect = "Allow"
    actions = [
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:GetRolePolicy"
    ]
    resources = [
      var.ecs_task_exec_role_arn,
      var.ecs_task_runtime_role_arn
    ]
  }

  statement {
    sid    = "IamReadAwsManagedPolicies"
    effect = "Allow"
    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions"
    ]
    resources = ["arn:aws:iam::aws:policy/*"]
  }

  statement {
    sid       = "LogsListTagsForResource"
    effect    = "Allow"
    actions   = ["logs:ListTagsForResource"]
    resources = [var.log_group_arn]
  }

  statement {
    sid    = "Ec2ReadVpcAttrs"
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAvailabilityZones"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "EcrListTagsForResource"
    effect    = "Allow"
    actions   = ["ecr:ListTagsForResource"]
    resources = [var.ecr_repo_arn]
  }

  statement {
    sid       = "ElbReadAttributesLb"
    effect    = "Allow"
    actions   = ["elasticloadbalancing:DescribeLoadBalancerAttributes"]
    resources = ["*"]
  }

  statement {
    sid       = "ElbReadAttributesTg"
    effect    = "Allow"
    actions   = ["elasticloadbalancing:DescribeTargetGroupAttributes"]
    resources = ["*"]
  }

  statement {
    sid    = "EcrLifecycleRead"
    effect = "Allow"
    actions = [
      "ecr:GetLifecyclePolicy",
      "ecr:GetLifecyclePolicyPreview"
    ]
    resources = [var.ecr_repo_arn]
  }

  statement {
    sid       = "ElbReadListenerAttributes"
    effect    = "Allow"
    actions   = ["elasticloadbalancing:DescribeListenerAttributes"]
    resources = ["*"]
  }

  statement {
    sid    = "EcsTagging"
    effect = "Allow"
    actions = [
      "ecs:TagResource",
      "ecs:UntagResource",
      "ecs:ListTagsForResource"
    ]
    resources = ["arn:aws:ecs:${var.aws_region}:${var.account_id}:*"]
  }

  statement {
    sid    = "AppAutoScalingEcs"
    effect = "Allow"
    actions = [
      "application-autoscaling:RegisterScalableTarget",
      "application-autoscaling:DeregisterScalableTarget",
      "application-autoscaling:PutScalingPolicy",
      "application-autoscaling:DeleteScalingPolicy",
      "application-autoscaling:Describe*"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "IamCreateServiceLinkedRoleForAppAS"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "ecs.amazonaws.com",
        "application-autoscaling.amazonaws.com",
        "elasticloadbalancing.amazonaws.com"
      ]
    }
  }

  statement {
    sid    = "CloudWatchAlarmsManage"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricData"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchAlarmsTagging"
    effect = "Allow"
    actions = [
      "cloudwatch:ListTagsForResource",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource"
    ]
    resources = [var.cloudwatch_alarm_arn_pattern]
  }

  statement {
    sid     = "IamReadSlrAppAS"
    effect  = "Allow"
    actions = ["iam:GetRole"]
    resources = [
      "arn:aws:iam::${var.account_id}:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService"
    ]
  }

  statement {
    sid       = "AppAutoScalingListTags"
    effect    = "Allow"
    actions   = ["application-autoscaling:ListTagsForResource"]
    resources = ["*"]
  }

}

resource "aws_iam_policy" "this" {
  name        = "${var.role_name}-min"
  description = "Least privilege IAM policy for Terraform deployments"
  policy      = data.aws_iam_policy_document.deploy_min.json
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
