################################################################################
# Storage Module
# S3 buckets for raw data + DVC remote and MLflow artifacts, plus ECR repo.
################################################################################

# ── S3: Data & DVC remote ──────────────────────────────────────────────────────

resource "aws_s3_bucket" "data" {
  bucket        = "${var.project}-data-${var.aws_account_id}"
  force_destroy = true
  tags          = merge(var.tags, { Name = "${var.project}-data" })
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── S3: MLflow artifact store ──────────────────────────────────────────────────

resource "aws_s3_bucket" "mlflow_artifacts" {
  bucket        = "${var.project}-mlflow-artifacts-${var.aws_account_id}"
  force_destroy = true
  tags          = merge(var.tags, { Name = "${var.project}-mlflow-artifacts" })
}

resource "aws_s3_bucket_versioning" "mlflow_artifacts" {
  bucket = aws_s3_bucket.mlflow_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mlflow_artifacts" {
  bucket = aws_s3_bucket.mlflow_artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "mlflow_artifacts" {
  bucket                  = aws_s3_bucket.mlflow_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── ECR: Docker image registry ─────────────────────────────────────────────────

resource "aws_ecr_repository" "model" {
  name                 = "${var.project}/churn-model"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, { Name = "${var.project}-ecr" })
}

# Lifecycle policy: keep last 10 images, expire untagged after 1 day
resource "aws_ecr_lifecycle_policy" "model" {
  repository = aws_ecr_repository.model.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["v"]
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}
