terraform {
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name = var.app_name

  tags = merge(var.common_tags, {
    Environment = "dev"
  })
}

module "ecs" {
  source = "../../modules/ecs"

  environment         = "dev"
  app_name           = var.app_name
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  public_subnet_ids  = var.public_subnet_ids
  ecr_repository_url = module.ecr.repository_url
  image_tag          = var.image_tag
  desired_count      = 2
  task_cpu           = "256"
  task_memory        = "512"
  aws_region         = var.aws_region

  tags = merge(var.common_tags, {
    Environment = "dev"
  })
}

module "lambda" {
  source = "../../modules/lambda"

  environment        = "dev"
  app_name          = var.app_name
  slack_webhook_url = var.slack_webhook_url

  tags = merge(var.common_tags, {
    Environment = "dev"
  })
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "alb_dns_name" {
  value = module.ecs.alb_dns_name
}
