resource "aws_ecs_cluster" "airflow_cluster" {
  name = "airflow-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "airflow_cluster_capacity_providers" {
  cluster_name       = aws_ecs_cluster.airflow_cluster.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = 0
  }
}

resource "aws_ecs_task_definition" "airflow_cluster_task_definition" {
  family                   = "airflow-cluster-task-definition"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "4096"
  memory                   = "8192"
  network_mode             = "awsvpc"
  task_role_arn            = aws_iam_role.airflow_cluster_task_role.arn
  execution_role_arn       = aws_iam_role.airflow_cluster_execution_role.arn
  pid_mode                 = "task"

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  ephemeral_storage {
    size_in_gib = 21
  }

  container_definitions = jsonencode([
    {
      name      = "airflow-standalone"
      essential = true
      command   = ["standalone"]
      image     = "${aws_ecr_repository.airflow_repo.repository_url}:latest"
      cpu       = 4096
      memory    = 4096
      user      = "airflow"

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "AIRFLOW__API__PORT", value = "8080" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/airflow-cluster/api-standalone"
          "awslogs-region"        = "eu-central-1"
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }

      healthCheck = {
        command     = ["CMD", "curl", "--fail", "http://localhost:8080/api/v2/monitor/health"]
        interval    = 30
        timeout     = 10
        retries     = 5
        startPeriod = 30
      }
    }
  ])
}
