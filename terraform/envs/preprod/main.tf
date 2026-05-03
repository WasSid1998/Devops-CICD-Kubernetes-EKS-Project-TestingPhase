terraform {
  backend "s3" {
    bucket = "pythonapp-tf-state"
    key = "preprod/terraform.tfstate"
    dynamodb_table = "terraform-lock"
    encrypt = true
    region = "us-east-1"
  }
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
    random = {
        source = "hashicorp/random"
    }
  }
}

provider "aws" { 
    region = "us-east-1"
}

variable "project" {}
variable "env" {}
variable "node_size" {}
variable "min_nodes" {}
variable "max_nodes" {}
variable "multi_az" {}
variable "backup_days" {}
variable "deletion_protection" {}
variable "domain_name" {}
variable "alert_email" {}
variable "route53_zone_id" {}

module "vpc" {
  source = "../../modules/vpc"
  project = var.project
  env = var.env
}

module "iam" {
    source = "../../modules/iam"
    project = var.project
    env = var.env
    oidc_url = module.eks.oidc_url
    oidc_arn = module.eks.oidc_arn
    secret_arn = module.rds.secret_arn
}

module "eks" {
    source = "../../modules/eks"
    project = var.project
    env = var.env
    private_subnets = module.vpc.private_subnet_ids
    eks_sg_id = module.vpc.eks_sg_id
    cluster_role_arn = module.iam.cluster_role_arn
    node_role_arn = module.iam.node_role_arn
    node_size = var.node_size
    min_nodes = var.min_nodes
    max_nodes = var.max_nodes
}

module "rds" {
    source = "../../modules/rds"
    project = var.project
    env = var.env
    private_subnets = module.vpc.private_subnet_ids
    rds_sg_id = module.vpc.rds_sg_id
    multi_az = var.multi_az
    backup_days = var.backup_days
    deletion_protection = var.deletion_protection
}

module "cloudwatch" {
    source = "../../modules/cloudwatch"
    project = var.project
    env = var.env
    alert_email = var.alert_email
    db_id = module.rds.db_endpoints
}

module "cloudfront" {
    source = "../../modules/cloudfront"
    project = var.project
    env = var.env
    alb_dns = module.eks.alb_dns
    domain_name = var.domain_name
    acm_cert_arn = module.cloudfront.acm_cert_arn
    route53_zone_id = module.route53.zone_id 
}
