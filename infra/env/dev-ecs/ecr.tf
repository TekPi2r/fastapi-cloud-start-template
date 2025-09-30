data "aws_ecr_repository" "fastapi_dev" {
  name = "${local.name}-ecr"
}
