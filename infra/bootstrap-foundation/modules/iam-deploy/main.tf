data "aws_partition" "current" {}

#checkov:skip=CKV_AWS_356: ECS/ELB APIs require wildcard resources for Describe operations
#checkov:skip=CKV_AWS_111: Terraform deploy role needs scoped write permissions for ECS deploy operations
# Baseline permissions required for Terraform plan/apply that are mostly read or
# backend related. Mutating actions that create/update runtime resources live in
# the separate `deploy_manage` policy to stay under the IAM policy size limit.
data "aws_iam_policy_document" "deploy_core" {
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
    sid    = "Ec2Describe"
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeVpcEndpoints"
    ]
    resources = ["*"]
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
    sid    = "ElbDescribe"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeListenerAttributes"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "LogsDescribe"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EcrDescribe"
    effect = "Allow"
    actions = [
      "ecr:DescribeRepositories",
      "ecr:ListTagsForResource",
      "ecr:GetLifecyclePolicy",
      "ecr:GetLifecyclePolicyPreview"
    ]
    resources = [var.ecr_repo_arn]
  }

  statement {
    sid    = "IamReadRoles"
    effect = "Allow"
    actions = [
      "iam:GetRole",
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
    sid    = "CloudWatchAlarms"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricData",
      "cloudwatch:ListTagsForResource",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource"
    ]
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
    sid    = "EcsDescribe"
    effect = "Allow"
    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition"
    ]
    resources = ["*"]
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

# Mutating permissions kept separate so the IAM policy stays below the 6 KB
# managed policy size limit.
#checkov:skip=CKV_AWS_356: Terraform must call write APIs that rely on wildcard resources
#checkov:skip=CKV_AWS_111: Mutating policy intentionally grants write permissions scoped to runtime resources
data "aws_iam_policy_document" "deploy_manage" {
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
    sid    = "IamManageEcsTaskRoles"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy"
    ]
    resources = [
      var.ecs_task_exec_role_arn,
      var.ecs_task_runtime_role_arn
    ]
  }

  statement {
    sid    = "EcsManage"
    effect = "Allow"
    actions = [
      "ecs:CreateCluster",
      "ecs:DeleteCluster",
      "ecs:CreateService",
      "ecs:DeleteService",
      "ecs:UpdateService",
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AppAutoScalingManage"
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
    sid       = "ServiceLinkedRole"
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
    sid       = "S3CreateAlbLogsBucket"
    effect    = "Allow"
    actions   = ["s3:CreateBucket"]
    resources = ["*"]
  }

  statement {
    sid    = "S3ManageAlbLogsBucket"
    effect = "Allow"
    actions = [
      "s3:DeleteBucket",
      "s3:PutBucketOwnershipControls",
      "s3:GetBucketOwnershipControls",
      "s3:DeleteBucketOwnershipControls",
      "s3:PutBucketVersioning",
      "s3:GetBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:GetEncryptionConfiguration",
      "s3:PutBucketPublicAccessBlock",
      "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketAcl",
      "s3:GetBucketAcl",
      "s3:PutBucketPolicy",
      "s3:GetBucketPolicy",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketLogging",
      "s3:GetBucketLogging",
      "s3:PutLifecycleConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetBucketCORS",
      "s3:PutBucketTagging",
      "s3:GetBucketTagging",
      "s3:DeleteBucketTagging",
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [var.alb_log_bucket_arn]
  }

  statement {
    sid    = "S3ManageAlbLogsObjects"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = [var.alb_log_bucket_objects_arn]
  }

  statement {
    sid    = "CloudWatchLogsManage"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:PutResourcePolicy",
      "logs:DeleteResourcePolicy"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:*"]
  }

  statement {
    sid    = "Ec2ManageNetworking"
    effect = "Allow"
    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:CreateVpcEndpoint",
      "ec2:DeleteVpcEndpoints",
      "ec2:ModifyVpcEndpoint"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ElbManage"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KmsManageEnvKeys"
    effect = "Allow"
    actions = [
      "kms:CreateKey",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:EnableKey",
      "kms:DisableKey",
      "kms:EnableKeyRotation",
      "kms:DisableKeyRotation",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:PutKeyPolicy",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:ListResourceTags",
      "kms:ListAliases",
      "kms:CreateAlias",
      "kms:UpdateAlias",
      "kms:DeleteAlias"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "core" {
  name        = "${var.role_name}-core"
  description = "Read/back-end permissions for Terraform deploy role"
  policy      = data.aws_iam_policy_document.deploy_core.json
  tags        = var.tags
}

resource "aws_iam_policy" "manage" {
  name        = "${var.role_name}-manage"
  description = "Mutable permissions for Terraform deploy role"
  policy      = data.aws_iam_policy_document.deploy_manage.json
  tags        = var.tags
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = var.assume_role_policy
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "core" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.core.arn
}

resource "aws_iam_role_policy_attachment" "manage" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.manage.arn
}
