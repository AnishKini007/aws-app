################################################################################
# GitHub Actions OIDC
#
# Allows GitHub Actions to assume an AWS IAM role without storing long-lived
# access keys as secrets. GitHub generates a short-lived OIDC token per run;
# AWS validates it against the trust policy below.
################################################################################

variable "github_repo" {
  description = "GitHub repo in owner/repo format (e.g. anishkini/aws-app)"
  type        = string
}

# ── OIDC Identity Provider ─────────────────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint (stable — this is GitHub's certificate fingerprint)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = local.common_tags
}

# ── IAM Role ───────────────────────────────────────────────────────────────────

resource "aws_iam_role" "github_actions" {
  name = "${var.project}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Scope to your repo only — main branch + PRs
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
      }
    }]
  })

  tags = local.common_tags
}

# ── Permissions the pipeline actually needs ────────────────────────────────────

resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # ECR — authenticate, push images
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
        ]
        Resource = module.storage.ecr_repository_arn
      },

      # ECS — deploy new task revision
      {
        Sid    = "ECSDeployUpdate"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
        ]
        Resource = "*"
      },

      # IAM PassRole — needed when registering ECS task definitions
      {
        Sid    = "PassECSRoles"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = "*"
        Condition = {
          StringLike = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      },

      # S3 — DVC push/pull for data bucket
      {
        Sid    = "DVCDataBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          module.storage.data_bucket_arn,
          "${module.storage.data_bucket_arn}/*",
        ]
      },

      # CloudWatch — write logs (for debugging CI runs)
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "*"
      },
    ]
  })
}

# ── Output the role ARN — add this as GitHub secret AWS_ROLE_ARN ───────────────

output "github_actions_role_arn" {
  description = "Add this as the AWS_ROLE_ARN secret in your GitHub repo settings"
  value       = aws_iam_role.github_actions.arn
}
