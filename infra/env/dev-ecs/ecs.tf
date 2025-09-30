module "ecs" {
  source = "./modules/ecs-service"

  name               = local.name
  tags               = local.tags
  aws_region         = var.aws_region
  image              = "${data.aws_ecr_repository.fastapi_dev.repository_url}:${var.image_tag}"
  log_group_name     = aws_cloudwatch_log_group.api.name
  desired_count      = var.desired_count
  task_cpu           = var.task_cpu
  task_memory        = var.task_memory
  subnet_ids         = local.private_subnets
  security_group_ids = [local.ecs_security_group_id]
  target_group_arn   = module.alb.target_group_arn
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task_runtime.arn
  environment = [
    {
      name  = "ENV"
      value = var.environment
    },
    {
      name  = "PORT"
      value = tostring(var.container_port)
    }
  ]
  container_name         = "api"
  container_port         = 8000
  enable_execute_command = true
}
