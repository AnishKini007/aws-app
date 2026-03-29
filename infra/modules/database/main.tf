################################################################################
# Database Module
# RDS Postgres instance used as MLflow's backend metadata store.
################################################################################

resource "aws_db_subnet_group" "mlflow" {
  name       = "${var.project}-mlflow-db-subnet"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.project}-db-subnet-group" })
}

resource "aws_db_parameter_group" "mlflow" {
  name   = "${var.project}-mlflow-pg15"
  family = "postgres15"
  tags   = var.tags
}

resource "aws_db_instance" "mlflow" {
  identifier        = "${var.project}-mlflow-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = var.instance_class
  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = "mlflow"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.mlflow.name
  vpc_security_group_ids = [var.security_group_id]
  parameter_group_name   = aws_db_parameter_group.mlflow.name

  # Cost-saving settings for a personal project
  multi_az               = false
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false

  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  tags = merge(var.tags, { Name = "${var.project}-mlflow-db" })
}
