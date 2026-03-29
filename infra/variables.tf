################################################################################
# Root variables — set values in terraform.tfvars (never commit secrets)
################################################################################

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Short project name used as a prefix for all resources"
  type        = string
  default     = "mlops"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
  default     = "dev"
}

# ── Networking ─────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  description = "Must match the chosen region (e.g. ap-south-1a, ap-south-1b)"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "ssh_allowed_cidrs" {
  description = "Your home/office IP in CIDR form for SSH access to MLflow EC2"
  type        = list(string)
  default     = []
}

# ── Database ───────────────────────────────────────────────────────────────────

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_username" {
  type    = string
  default = "mlflow"
}

variable "db_password" {
  description = "RDS master password — provide via TF_VAR_db_password env var"
  type        = string
  sensitive   = true
}

# ── MLflow EC2 ─────────────────────────────────────────────────────────────────

variable "mlflow_instance_type" {
  type    = string
  default = "t3.small"
}

variable "key_pair_name" {
  description = "EC2 key pair for SSH access (optional)"
  type        = string
  default     = null
}

# ── ECS ────────────────────────────────────────────────────────────────────────

variable "ecs_task_cpu" {
  type    = number
  default = 512
}

variable "ecs_task_memory" {
  type    = number
  default = 1024
}

variable "ecs_desired_count" {
  type    = number
  default = 1
}
