#!/bin/bash
set -euo pipefail

# ── System setup ───────────────────────────────────────────────────────────────
yum update -y
yum install -y python3 python3-pip postgresql15 jq

pip3 install --upgrade pip
pip3 install mlflow[extras]==2.13.0 boto3 psycopg2-binary

# ── Pull DB credentials from SSM Parameter Store ──────────────────────────────
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

DB_PASSWORD=$(aws ssm get-parameter \
  --name "/${PROJECT}/mlflow/db_password" \
  --with-decryption \
  --region "$$REGION" \
  --query "Parameter.Value" \
  --output text)

# ── Configure MLflow as a systemd service ─────────────────────────────────────
cat > /etc/systemd/system/mlflow.service << EOF
[Unit]
Description=MLflow Tracking Server
After=network.target

[Service]
Type=simple
User=ec2-user
Environment=AWS_DEFAULT_REGION=$${REGION}
ExecStart=/usr/local/bin/mlflow server \
  --backend-store-uri postgresql://${DB_USERNAME}:$${DB_PASSWORD}@${DB_ENDPOINT}/mlflow \
  --default-artifact-root s3://${ARTIFACT_BUCKET}/mlflow-artifacts \
  --host 0.0.0.0 \
  --port 5000 \
  --workers 2
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mlflow
systemctl start mlflow
