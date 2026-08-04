locals {
  github_oidc_url = "https://token.actions.githubusercontent.com"
  oidc_audiences  = ["sts.amazonaws.com"]
  iam_path        = "/data_platform/"
}

resource "aws_iam_openid_connect_provider" "gh_action_oidc" {
  url            = local.github_oidc_url
  client_id_list = local.oidc_audiences
  tags = {
    Purpose = "GitHub Action OIDC Authentication"
  }
}

resource "aws_iam_role_policy_attachment" "attach_gh_action_auth_publish_policy" {
  role       = aws_iam_role.gh_action_role.name
  policy_arn = aws_iam_policy.gh_action_auth_publish_policy.arn
}

resource "aws_iam_role" "gh_action_role" {
  name        = "Github-Action-OIDC-Role"
  description = "Role to be assumed by GitHub Actions for OIDC authentication to AWS (ECR Deployment)"
  path        = local.iam_path
  # Trust Policy
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "sts:AssumeRoleWithWebIdentity",
          "Principal" : {
            "Federated" : aws_iam_openid_connect_provider.gh_action_oidc.arn
          },
          "Condition" : {
            "StringEquals" : {
              "token.actions.githubusercontent.com:aud" : [
                "sts.amazonaws.com"
              ]
            },
            "StringLike" : {
              "token.actions.githubusercontent.com:sub" : var.github_repos
            }
          }
        }
      ]
    }
  )
}

resource "aws_iam_policy" "gh_action_auth_publish_policy" {
  name = "ECRAuthPublishPolicy"
  path = local.iam_path
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "ECRAuth",
        "Effect" : "Allow",
        "Action" : "ecr:GetAuthorizationToken",
        "Resource" : "*"
      },
      {
        "Sid" : "ECRPushPull",
        "Effect" : "Allow",
        "Action" : [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ],
        "Resource" : aws_ecr_repository.airflow_repo.arn
      },
      {
        "Sid" : "RegisterTaskDefinition",
        "Effect" : "Allow",
        "Action" : [
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:TagResource"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "PassRolesToECS",
        "Effect" : "Allow",
        "Action" : "iam:PassRole",
        "Resource" : [
          aws_iam_role.airflow_cluster_execution_role.arn,
          aws_iam_role.airflow_cluster_task_role.arn
        ],
        "Condition" : {
          "StringEquals" : {
            "iam:PassedToService" : "ecs-tasks.amazonaws.com"
          }
        }
      },
      {
        "Sid" : "DeployToECS",
        "Effect" : "Allow",
        "Action" : [
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ],
        "Resource" : "arn:aws:ecs:*:${data.aws_caller_identity.current.account_id}:service/${aws_ecs_cluster.airflow_cluster.name}/*"
      },
      {
        "Sid" : "DescribeClusterForDeploy",
        "Effect" : "Allow",
        "Action" : "ecs:DescribeClusters",
        "Resource" : aws_ecs_cluster.airflow_cluster.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_airflow_cluster_execution_role_policy" {
  role       = aws_iam_role.airflow_cluster_execution_role.name
  policy_arn = aws_iam_policy.airflow_cluster_execution_role_policy.arn
}

resource "aws_iam_role" "airflow_cluster_execution_role" {
  name = "AirflowClusterECSExecutionRole"
  path = local.iam_path
  # Trust Policy
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "AllowECSToAssumeRole",
          "Effect" : "Allow",
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "ecs-tasks.amazonaws.com"
          }
        }
      ]
    }
  )
}

resource "aws_iam_policy" "airflow_cluster_execution_role_policy" {
  name = "AirflowClusterECSExecutionRolePolicy"
  path = local.iam_path
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "AllowECRImagePull",
          "Effect" : "Allow",
          "Action" : [
            "ecr:BatchGetImage",
            "ecr:GetDownloadUrlForLayer",
            "ecr:GetAuthorizationToken"
          ],
          "Resource" : "*"
        },
        {
          "Sid" : "AllowSecretsManagerAccess",
          "Effect" : "Allow",
          "Action" : [
            "secretsmanager:GetSecretValue"
          ],
          "Resource" : "*"
        },
        {
          "Sid" : "AllowCloudWatchLogs",
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : "*"
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "attach_airflow_cluster_task_role_policy" {
  role       = aws_iam_role.airflow_cluster_task_role.name
  policy_arn = aws_iam_policy.airflow_cluster_task_role_policy.arn
}

resource "aws_iam_role" "airflow_cluster_task_role" {
  name = "AirflowClusterECSTaskRole"
  path = local.iam_path
  # Trust Policy
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "AllowECSTaskToAssumeRole",
          "Effect" : "Allow",
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "ecs-tasks.amazonaws.com"
          }
        }
      ]
    }
  )
}

resource "aws_iam_policy" "airflow_cluster_task_role_policy" {
  name = "AirflowClusterECSTaskRolePolicy"
  path = local.iam_path
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "ssmmessages:CreateControlChannel",
            "ssmmessages:CreateDataChannel",
            "ssmmessages:OpenControlChannel",
            "ssmmessages:OpenDataChannel"
          ],
          "Resource" : "*"
        }
      ]
    }
  )
}
