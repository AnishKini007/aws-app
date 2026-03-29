# MLOps Pipeline on AWS

End-to-end MLOps project demonstrating ML model training, versioning, and production deployment on AWS. Built to complement the AWS Solutions Architect Associate certification.

## Architecture

```
GitHub Push
    │
    ▼
GitHub Actions
    ├── lint + unit tests
    ├── DVC pipeline  →  preprocess → train → quality gate (MLflow)
    ├── Docker build  →  push to ECR
    └── ECS deploy    →  force new Fargate deployment

AWS Infrastructure (Terraform):
  VPC  ──┬──  public subnets   ──  MLflow EC2  (port 5000, VPC-only)
         │                     ──  ALB          (port 80, public)
         └──  private subnets  ──  ECS Fargate  (churn-model API)
                               ──  RDS Postgres (MLflow backend store)

  S3:   data bucket (DVC remote)  |  artifacts bucket (MLflow)
  ECR:  churn-model Docker images
```

## Tech Stack

| Layer | Technology |
|---|---|
| Infrastructure | Terraform, AWS (VPC, EC2, ECS Fargate, RDS, S3, ECR, IAM) |
| ML Experiment Tracking | MLflow (self-hosted on EC2, backed by RDS + S3) |
| Data Versioning | DVC with S3 remote |
| Model | Gradient Boosting (scikit-learn), Telco Churn dataset |
| Model Serving | FastAPI + Uvicorn, containerised via Docker |
| CI/CD | GitHub Actions (OIDC auth, no long-lived AWS keys) |
| Monitoring | AWS CloudWatch + Container Insights |

## Project Structure

```
aws-app/
├── .github/workflows/
│   └── train-and-deploy.yml   # Full CI/CD pipeline
├── infra/                     # Terraform (modular)
│   ├── modules/
│   │   ├── networking/        # VPC, subnets, security groups
│   │   ├── storage/           # S3, ECR
│   │   ├── database/          # RDS Postgres
│   │   ├── mlflow/            # EC2 + MLflow systemd service
│   │   └── ecs/               # ECS Fargate + ALB
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── model/                     # ML pipeline
│   ├── src/
│   │   ├── preprocess.py      # Data cleaning + train/test split
│   │   ├── train.py           # GBM training with MLflow tracking
│   │   └── evaluate.py        # Quality gate + model promotion
│   ├── tests/                 # pytest unit tests
│   ├── dvc.yaml               # DVC pipeline definition
│   └── params.yaml            # Hyperparameters + thresholds
└── serving/                   # Model serving
    ├── app/
    │   ├── main.py            # FastAPI app
    │   └── schemas.py         # Pydantic request/response schemas
    └── Dockerfile             # Multi-stage build
```

## Getting Started

### Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.6
- Python >= 3.11
- Docker
- DVC (`pip install dvc[s3]`)

### 1. Provision Infrastructure

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

export TF_VAR_db_password="<strong-password>"

terraform init
terraform plan
terraform apply
```

Save the outputs — you'll need them as GitHub Secrets:

```bash
terraform output
```

### 2. Download the Dataset

Download the [Telco Customer Churn dataset](https://www.kaggle.com/datasets/blastchar/telco-customer-churn) and place it at:

```
model/data/raw/WA_Fn-UseC_-Telco-Customer-Churn.csv
```

### 3. Push Data to DVC Remote

```bash
cd model
dvc remote add -d s3remote s3://<your-data-bucket>/dvc-cache
dvc add data/raw/WA_Fn-UseC_-Telco-Customer-Churn.csv
dvc push
git add data/raw/.gitignore data/raw/WA_Fn-UseC_-Telco-Customer-Churn.csv.dvc
git commit -m "Add raw data via DVC"
```

### 4. Run the Pipeline Locally

```bash
cd model
pip install -r requirements.txt

export MLFLOW_TRACKING_URI=http://<mlflow-ec2-ip>:5000
dvc repro
```

### 5. Configure GitHub Secrets

| Secret | Where to get it |
|---|---|
| `AWS_ROLE_ARN` | Create an OIDC IAM role for GitHub Actions |
| `AWS_REGION` | e.g. `ap-south-1` |
| `ECR_REPOSITORY_URL` | `terraform output ecr_repository_url` |
| `MLFLOW_TRACKING_URI` | `terraform output mlflow_tracking_uri` |
| `ECS_CLUSTER_NAME` | `terraform output ecs_cluster_name` |
| `ECS_SERVICE_NAME` | `terraform output ecs_service_name` |
| `DATA_BUCKET_NAME` | `terraform output data_bucket_name` |

### 6. Deploy

Push to `main` — the GitHub Actions pipeline will:
1. Run unit tests
2. Preprocess data, train model, run quality gate
3. Build Docker image and push to ECR
4. Force a new ECS Fargate deployment

### 7. Call the API

```bash
# Health check
curl http://<alb-dns-name>/health

# Predict churn
curl -X POST http://<alb-dns-name>/predict \
  -H "Content-Type: application/json" \
  -d '{
    "tenure": 12, "MonthlyCharges": 65.0, "TotalCharges": 780.0,
    "gender": 0, "Partner": 1, "Dependents": 0, "PhoneService": 1,
    "MultipleLines": 0, "InternetService": 0, "OnlineSecurity": 0,
    "OnlineBackup": 1, "DeviceProtection": 0, "TechSupport": 0,
    "StreamingTV": 0, "StreamingMovies": 0, "Contract": 0,
    "PaperlessBilling": 1, "PaymentMethod": 0
  }'
```

## Cost Estimate

Running 24/7 in ap-south-1:

| Resource | ~Monthly Cost |
|---|---|
| EC2 t3.small (MLflow) | ~$8 |
| RDS db.t3.micro | ~$13 |
| ECS Fargate (0.25 vCPU) | ~$5 |
| NAT Gateway | ~$5 |
| S3 + ECR | < $1 |
| **Total** | **~$32/month** |

Tear down when not interviewing: `terraform destroy`

## Teardown

```bash
cd infra
terraform destroy
```
