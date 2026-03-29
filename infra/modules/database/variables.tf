variable "project" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for the RDS instance"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "mlflow"
}

variable "db_password" {
  description = "Master password for the RDS instance (use SSM/Secrets Manager in prod)"
  type        = string
  sensitive   = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
