variable "aws_region" { type = string }
variable "aws_account_id" { type = string }

variable "name_prefix" {
  type    = string
  default = "fastapi-dev"
}
variable "ecr_repo_name" {
  type    = string
  default = "fastapi-dev"
}
variable "image_tag" {
  type    = string
  default = "latest"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

# Si tu n’en fournis pas, on utilisera le VPC par défaut du compte
variable "vpc_id" {
  type    = string
  default = null
}

locals {
  tags = {
    Name        = "fastapi-dev"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
