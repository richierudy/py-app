terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "../../modules/networking"

  environment          = "prod"
  app_name             = var.app_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones

  tags = merge(var.common_tags, { Environment = "prod" })
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name = var.app_name

  tags = merge(var.common_tags, { Environment = "prod" })
}

module "ecs" {
  source = "../../modules/ecs"

  environment        = "prod"
  app_name           = var.app_name
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids
  ecr_repository_url = module.ecr.repository_url
  image_tag          = var.image_tag
  desired_count      = 4
  task_cpu           = "1024"
  task_memory        = "2048"
  aws_region         = var.aws_region

  tags = merge(var.common_tags, { Environment = "prod" })
}

module "lambda" {
  source = "../../modules/lambda"

  environment       = "prod"
  app_name          = var.app_name
  slack_webhook_url = var.slack_webhook_url

  tags = merge(var.common_tags, { Environment = "prod" })
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "alb_dns_name" {
  value = module.ecs.alb_dns_name
}

output "vpc_id" {
  value = module.networking.vpc_id
}
