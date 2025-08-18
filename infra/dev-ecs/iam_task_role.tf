resource "aws_iam_role" "task_runtime" {
  name               = "${var.name_prefix}-dev-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json

  tags = {
    Name        = "${var.name_prefix}-dev"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}
