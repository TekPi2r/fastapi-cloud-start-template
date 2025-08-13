# VPC de repli: VPC par défaut si vpc_id n'est pas fourni
data "aws_vpc" "default" {
  default = true
}

locals {
  vpc_id_effective = var.vpc_id != null && var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default.id
}

resource "aws_security_group" "api" {
  name        = "${var.name_prefix}-sg"
  description = "Allow HTTP 80 to container 8000" # <- caractères valides
  vpc_id      = local.vpc_id_effective

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All"
  }

  tags = local.tags
}
