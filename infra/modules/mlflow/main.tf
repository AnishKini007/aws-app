################################################################################
# MLflow Module
# EC2 instance running MLflow tracking server as a systemd service.
# Backend: RDS Postgres | Artifact store: S3
################################################################################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── IAM role for MLflow EC2 ────────────────────────────────────────────────────

resource "aws_iam_role" "mlflow" {
  name = "${var.project}-mlflow-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "mlflow_s3" {
  name = "${var.project}-mlflow-s3"
  role = aws_iam_role.mlflow.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          var.artifact_bucket_arn,
          "${var.artifact_bucket_arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:*:*:parameter/${var.project}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "mlflow" {
  name = "${var.project}-mlflow-profile"
  role = aws_iam_role.mlflow.name
}

# ── SSM Parameter for DB password ─────────────────────────────────────────────

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project}/mlflow/db_password"
  type  = "SecureString"
  value = var.db_password
  tags  = var.tags
}

# ── EC2 instance ───────────────────────────────────────────────────────────────

resource "aws_instance" "mlflow" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.mlflow.name
  key_name               = var.key_pair_name

  user_data = templatefile("${path.module}/user_data.sh", {
    PROJECT         = var.project
    DB_USERNAME     = var.db_username
    DB_ENDPOINT     = var.db_endpoint
    ARTIFACT_BUCKET = var.artifact_bucket_name
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(var.tags, { Name = "${var.project}-mlflow" })

  depends_on = [aws_ssm_parameter.db_password]
}
