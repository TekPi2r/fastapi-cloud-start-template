# Amazon Linux 2 (stable pour installer Docker)
data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "api" {
  ami                    = data.aws_ami.al2.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.api.id]

  # Public pour démarrer simple; passera à "false" quand tu mettras un ALB devant
  associate_public_ip_address = true

  # IMDSv2 only
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # EBS chiffré par défaut
  root_block_device {
    encrypted = true
  }

  # user_data rend l'instance idempotente (docker pull/run)
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    region         = var.aws_region
    account_id     = var.aws_account_id
    ecr_repo_name  = var.ecr_repo_name
    image_tag      = var.image_tag
    log_group_name = aws_cloudwatch_log_group.api.name
  })

  tags = local.tags
}
