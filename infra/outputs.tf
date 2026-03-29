output "mlflow_tracking_uri" {
  description = "MLflow tracking server URI (accessible within VPC)"
  value       = module.mlflow.tracking_uri
}

output "model_api_endpoint" {
  description = "Public URL for the churn model prediction API"
  value       = "http://${module.ecs.alb_dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing Docker images"
  value       = module.storage.ecr_repository_url
}

output "data_bucket_name" {
  description = "S3 bucket for raw data and DVC remote"
  value       = module.storage.data_bucket_name
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}
