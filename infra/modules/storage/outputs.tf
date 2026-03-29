output "data_bucket_name" {
  value = aws_s3_bucket.data.bucket
}

output "data_bucket_arn" {
  value = aws_s3_bucket.data.arn
}

output "mlflow_artifacts_bucket_name" {
  value = aws_s3_bucket.mlflow_artifacts.bucket
}

output "mlflow_artifacts_bucket_arn" {
  value = aws_s3_bucket.mlflow_artifacts.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.model.repository_url
}

output "ecr_repository_arn" {
  value = aws_ecr_repository.model.arn
}
