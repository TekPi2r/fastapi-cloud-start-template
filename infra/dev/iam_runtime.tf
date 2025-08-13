data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = local.tags
}

# Pull ECR
resource "aws_iam_role_policy_attachment" "ecr_ro" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Accès SSM (pas de SSH)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Ecriture vers CloudWatch Logs (log-driver=awslogs)
resource "aws_iam_policy" "cw_logs_min" {
  name = "${var.name_prefix}-cw-logs-min"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogGroup", "logs:DescribeLogGroups"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "${aws_cloudwatch_log_group.api.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cw_logs_min_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.cw_logs_min.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
