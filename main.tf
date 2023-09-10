terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.16.1"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project = "VPC Endpoint Sandbox"
    }
  }
}

### Locals ###

data "aws_caller_identity" "current" {}

locals {
  affix      = "examplecorp"
  account_id = data.aws_caller_identity.current.account_id
}

module "vpc" {
  source     = "./modules/vpc"
  aws_region = var.aws_region
  affix      = local.affix
}

module "app" {
  source    = "./modules/instance"
  affix     = local.affix
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.subnet_app
  ami       = var.ami
}

module "sqs" {
  source           = "./modules/sqs"
  ec2_iam_role_arn = module.app.iam_role_arn
}

module "vpce_sqs" {
  source           = "./modules/vpce/sqs"
  affix            = local.affix
  vpc_id           = module.vpc.vpc_id
  subnet_id        = module.vpc.subnet_app
  aws_region       = var.aws_region
  sqs_queue_arn    = module.sqs.sqs_queue_arn
  ec2_iam_role_arn = module.app.iam_role_arn
}
