################################################################################
# Root Terraform configuration
# Wires together all modules for the MLOps stack.
################################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment to store state in S3 after first apply
  # backend "s3" {
  #   bucket = "<your-state-bucket>"
  #   key    = "mlops/terraform.tfstate"
  #   region = var.aws_region
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── Networking ─────────────────────────────────────────────────────────────────

module "networking" {
  source = "./modules/networking"

  project              = var.project
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  ssh_allowed_cidrs    = var.ssh_allowed_cidrs
  tags                 = local.common_tags
}

# ── Storage ────────────────────────────────────────────────────────────────────

module "storage" {
  source = "./modules/storage"

  project        = var.project
  aws_account_id = data.aws_caller_identity.current.account_id
  tags           = local.common_tags
}

# ── Database (MLflow backend) ──────────────────────────────────────────────────

module "database" {
  source = "./modules/database"

  project           = var.project
  subnet_ids        = module.networking.private_subnet_ids
  security_group_id = module.networking.rds_sg_id
  instance_class    = var.db_instance_class
  db_username       = var.db_username
  db_password       = var.db_password
  tags              = local.common_tags
}

# ── MLflow Tracking Server ─────────────────────────────────────────────────────

module "mlflow" {
  source = "./modules/mlflow"

  project              = var.project
  subnet_id            = module.networking.public_subnet_ids[0]
  security_group_id    = module.networking.mlflow_sg_id
  instance_type        = var.mlflow_instance_type
  key_pair_name        = var.key_pair_name
  db_endpoint          = module.database.db_endpoint
  db_username          = var.db_username
  db_password          = var.db_password
  artifact_bucket_name = module.storage.mlflow_artifacts_bucket_name
  artifact_bucket_arn  = module.storage.mlflow_artifacts_bucket_arn
  tags                 = local.common_tags
}

# ── ECS Fargate (model serving) ────────────────────────────────────────────────

module "ecs" {
  source = "./modules/ecs"

  project             = var.project
  aws_region          = var.aws_region
  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  private_subnet_ids  = module.networking.private_subnet_ids
  alb_sg_id           = module.networking.alb_sg_id
  ecs_sg_id           = module.networking.ecs_sg_id
  ecr_repository_url  = module.storage.ecr_repository_url
  mlflow_tracking_uri = module.mlflow.tracking_uri
  artifact_bucket_arn = module.storage.mlflow_artifacts_bucket_arn
  task_cpu            = var.ecs_task_cpu
  task_memory         = var.ecs_task_memory
  desired_count       = var.ecs_desired_count
  tags                = local.common_tags
}
