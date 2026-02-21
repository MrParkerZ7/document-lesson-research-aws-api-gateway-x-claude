# ==============================================================================
# ECS Task Definition
# ==============================================================================

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.name_prefix}-${var.service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.service_config.cpu
  memory                   = var.service_config.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name  = local.container_name
      image = "${var.ecr_repository_url}:latest"

      essential = true

      portMappings = [
        {
          containerPort = var.service_config.container_port
          hostPort      = var.service_config.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod"
        },
        {
          name  = "SERVER_PORT"
          value = tostring(var.service_config.container_port)
        },
        # Context path to handle the service prefix from ALB
        {
          name  = "SERVER_SERVLET_CONTEXT_PATH"
          value = var.service_config.path_prefix
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = var.service_name
        }
      }

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:${var.service_config.container_port}${var.service_config.path_prefix}${var.service_config.health_check_path} || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name    = "${var.name_prefix}-${var.service_name}-task"
    Service = var.service_name
  }
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.name_prefix}/${var.service_name}"
  retention_in_days = 7

  tags = {
    Name    = "${var.name_prefix}-${var.service_name}-logs"
    Service = var.service_name
  }
}
