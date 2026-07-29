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

  volume {
    name = "airflow-dags"
  }

  volume {
    name = "airflow-logs"
  }

  container_definitions = jsonencode([
    {
      name      = "airflow-standalone"
      essential = true
      command   = ["airflow", "standalone"]
      image     = "${aws_ecr_repository.airflow_repo.repository_url}:latest"
      cpu       = 512
      memory    = 1024

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "airflow-dags"
          containerPath = "/opt/airflow/dags"
          readOnly      = true
        },
        {
          sourceVolume  = "airflow-logs"
          containerPath = "/opt/airflow/logs"
        }
      ]

      environment = [
        { name = "AIRFLOW__CORE__EXECUTOR", value = "CeleryExecutor" },
        { name = "AIRFLOW__CORE__LOAD_EXAMPLES", value = "false" },
        { name = "AIRFLOW__API__EXPOSE_CONFIG", value = "false" },
        # { name = "AIRFLOW__CELERY__BROKER_URL", value = "sqs://<BROKER_ENDPOINT>" },
        # { name = "AIRFLOW__CELERY__RESULT_BACKEND", value = "db+postgresql://<DB_HOST>:5432/airflow" }
      ]

      # secrets = [
      #   { name = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN", valueFrom = "arn:aws:secretsmanager:<REGION>:<ACCOUNT_ID>:secret:airflow/db-conn" },
      #   { name = "AIRFLOW__CORE__FERNET_KEY", valueFrom = "arn:aws:secretsmanager:<REGION>:<ACCOUNT_ID>:secret:airflow/fernet-key" },
      #   { name = "AIRFLOW__API_AUTH__JWT_SECRET", valueFrom = "arn:aws:secretsmanager:<REGION>:<ACCOUNT_ID>:secret:airflow/jwt-secret" }
      # ]

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
