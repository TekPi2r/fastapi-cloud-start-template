# runtime task role
resource "aws_iam_role" "task_runtime" {
  name               = "${local.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = local.tags
}
