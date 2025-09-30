data "aws_vpc" "default" {
  count   = var.vpc_id == "" ? 1 : 0
  default = true
}

data "aws_vpc" "selected" {
  id = local.effective_vpc_id
}

locals {
  effective_vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default[0].id
}

data "aws_subnets" "all_in_vpc" {
  filter {
    name   = "vpc-id"
    values = [local.effective_vpc_id]
  }
}

data "aws_subnet" "details" {
  for_each = toset(data.aws_subnets.all_in_vpc.ids)
  id       = each.value
}

locals {
  private_subnets = [
    for subnet in data.aws_subnet.details : subnet.id
    if subnet.map_public_ip_on_launch == false
  ]

  public_subnets = [
    for subnet in data.aws_subnet.details : subnet.id
    if subnet.map_public_ip_on_launch == true
  ]

  selected_public_subnets = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : (
    length(local.public_subnets) >= 2 ? slice(local.public_subnets, 0, 2) : local.public_subnets
  )
}

#checkov:skip=CKV2_AWS_5: Security group attached to ALB resource in same module
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Allow HTTP/HTTPS ingress"
  vpc_id      = local.effective_vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.allow_https ? [1] : []
    content {
      description = "HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = var.tags
}

#checkov:skip=CKV2_AWS_5: Security group attached to ECS service network interfaces
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.name}-ecs-sg"
  description = "Allow traffic from ALB"
  vpc_id      = local.effective_vpc_id

  egress {
    description = "DNS to VPC resolver (UDP)"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    description = "DNS to VPC resolver (TCP)"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  tags = var.tags
}

resource "aws_security_group" "vpce" {
  name        = "${var.name}-vpce-sg"
  description = "Allow HTTPS from ECS tasks to VPC endpoints"
  vpc_id      = local.effective_vpc_id
  tags        = var.tags
}

resource "aws_security_group_rule" "alb_to_ecs_tasks" {
  description              = "Forward app traffic to ECS tasks"
  type                     = "egress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "ecs_tasks_from_alb" {
  description              = "Receive traffic from ALB"
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_tasks.id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "ecs_tasks_to_vpce" {
  description              = "Allow HTTPS to VPC endpoints"
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_tasks.id
  source_security_group_id = aws_security_group.vpce.id
}

resource "aws_security_group_rule" "vpce_from_ecs_tasks" {
  description              = "Receive HTTPS from ECS tasks"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpce.id
  source_security_group_id = aws_security_group.ecs_tasks.id
}

locals {
  vpce_services = [
    "com.amazonaws.${var.aws_region}.ecr.api",
    "com.amazonaws.${var.aws_region}.ecr.dkr",
    "com.amazonaws.${var.aws_region}.logs",
    "com.amazonaws.${var.aws_region}.ssm",
    "com.amazonaws.${var.aws_region}.ssmmessages",
    "com.amazonaws.${var.aws_region}.ec2messages",
  ]
}

resource "aws_vpc_endpoint" "interfaces" {
  for_each            = toset(local.vpce_services)
  vpc_id              = local.effective_vpc_id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.private_subnets
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true
  tags                = var.tags
}
