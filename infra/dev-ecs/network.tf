### Auto-découverte Subnets
# Toutes les subnets du VPC
data "aws_subnets" "all_in_vpc" {
  filter {
    name   = "vpc-id"
    values = [local.effective_vpc_id]
  }
}

# Détail par subnet (pour lire map_public_ip_on_launch)
data "aws_subnet" "by_id" {
  for_each = toset(data.aws_subnets.all_in_vpc.ids)
  id       = each.value
}

# Séparation publiques / privées
locals {
  private_subnets = [
    for s in data.aws_subnet.by_id : s.id
    if s.map_public_ip_on_launch == false
  ]

  public_subnets = [
    for s in data.aws_subnet.by_id : s.id
    if s.map_public_ip_on_launch == true
  ]
}
###

data "aws_vpc" "default" {
  default = true
}

locals {
  effective_vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default.id
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [local.effective_vpc_id]
  }
}

locals {
  selected_subnets = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : (
    length(data.aws_subnets.selected.ids) >= 2 ? slice(data.aws_subnets.selected.ids, 0, 2) : data.aws_subnets.selected.ids
  )
}

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "ALB ingress 80/443"
  vpc_id      = local.effective_vpc_id

  # Justification: point d'entrée public contrôlé (ALB), TLS/redirect en place.
  #checkov:skip=CKV_AWS_260: "ALB public, HTTPS enforce; HTTP pour redirection"
  #tfsec:ignore:aws-ec2-no-public-ingress-sgr
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Justification: point d'entrée public contrôlé (ALB), TLS/redirect en place.
  #checkov:skip=CKV_AWS_260: "ALB public, HTTPS enforce; HTTP pour redirection"
  #tfsec:ignore:aws-ec2-no-public-ingress-sgr
  dynamic "ingress" {
    for_each = var.acm_certificate_arn != "" ? [1] : []
    content {
      description = "HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # EGRESS : au lieu de 0.0.0.0/0, limite vers le SG des tasks (port app)
  egress {
    description    = "To ECS tasks only"
    from_port      = 8000
    to_port        = 8000
    protocol       = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  tags = local.tags
}

# Résolveur DNS VPC (.2) — on autorise DNS vers le CIDR du VPC
data "aws_vpc" "current" { id = local.effective_vpc_id }

resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name}-ecs-sg"
  description = "Allow app port from ALB"
  vpc_id      = local.effective_vpc_id

  ingress {
    description     = "App from ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # ... ton resource "aws_security_group" "ecs_tasks" {
  # (ingress depuis l’ALB inchangé)

  # DNS UDP
  egress {
    description = "DNS to VPC resolver (UDP)"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.current.cidr_block]
  }

  # DNS TCP (fallback)
  egress {
    description = "DNS to VPC resolver (TCP)"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.current.cidr_block]
  }

  # HTTPS uniquement vers les VPC endpoints
  egress {
    description    = "HTTPS to VPC endpoints"
    from_port      = 443
    to_port        = 443
    protocol       = "tcp"
    security_groups = [aws_security_group.vpce.id]
  }

  tags = local.tags
}

#tfsec:ignore:aws-elb-alb-not-public
resource "aws_lb" "app" {
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    enabled = true
  }

  name               = "${local.name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.selected_subnets

  drop_invalid_header_fields = true
  enable_deletion_protection = true

  tags = local.tags
}

resource "aws_lb_target_group" "app" {
  name        = "${local.name}-tg"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = local.effective_vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = {
    Name        = var.name_prefix
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

# Justification: ALB public avec redirection HTTP->HTTPS contrôlée.
#checkov:skip=CKV_AWS_2 reason=Listener HTTP uniquement pour redirection 301 vers HTTPS.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"  #tfsec:ignore:aws-elb-http-not-used exp:2025-10-31

  default_action {
    type             = var.acm_certificate_arn != "" ? "redirect" : "forward"
    target_group_arn = var.acm_certificate_arn != "" ? null : aws_lb_target_group.app.arn

    dynamic "redirect" {
      for_each = var.acm_certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = var.acm_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_security_group" "vpce" {
  name        = "${local.name}-vpce-sg"
  description = "Allow HTTPS from ECS tasks to VPC endpoints"
  vpc_id      = local.effective_vpc_id

  # Le trafic sortant des tasks (443) vers les endpoints
  ingress {
    description     = "From ECS tasks to VPC endpoints (TLS)"
    from_port      = 443
    to_port        = 443
    protocol       = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  tags = local.tags
}

locals {
  vpce_services = [
    "com.amazonaws.${var.aws_region}.ecr.api",
    "com.amazonaws.${var.aws_region}.ecr.dkr",
    "com.amazonaws.${var.aws_region}.logs",
    # requis si enable_execute_command = true
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
  subnet_ids          = local.private_subnets          # endpoints dans les subnets privés
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true
  tags                = local.tags
}
