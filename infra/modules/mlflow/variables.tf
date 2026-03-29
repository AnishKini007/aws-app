variable "project" {
  type = string
}

variable "subnet_id" {
  description = "Public subnet ID for the MLflow EC2 instance"
  type        = string
}

variable "security_group_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "key_pair_name" {
  description = "EC2 key pair name for SSH access (optional)"
  type        = string
  default     = null
}

variable "db_endpoint" {
  description = "RDS endpoint (host:port)"
  type        = string
}

variable "db_username" {
  type    = string
  default = "mlflow"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "artifact_bucket_name" {
  type = string
}

variable "artifact_bucket_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
