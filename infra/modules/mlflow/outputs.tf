output "instance_id" {
  value = aws_instance.mlflow.id
}

output "private_ip" {
  value = aws_instance.mlflow.private_ip
}

output "tracking_uri" {
  description = "MLflow tracking URI (accessible from within the VPC)"
  value       = "http://${aws_instance.mlflow.private_ip}:5000"
}
