terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ⚠️ Pas de backend déclaré ici :
  # le backend S3+DynamoDB est injecté depuis run.sh (terraform init -backend-config=...)
}

provider "aws" {
  region = var.aws_region
  # Les credentials/profil viennent de l'env (AWS_PROFILE, SSO, etc.)
}
