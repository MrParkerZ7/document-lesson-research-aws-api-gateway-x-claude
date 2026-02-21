# ==============================================================================
# IAM Roles for ECS
# ==============================================================================

# Execution Role - Used by ECS to pull images and write logs
resource "aws_iam_role" "execution" {
  name = "${var.name_prefix}-${var.service_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.name_prefix}-${var.service_name}-execution-role"
    Service = var.service_name
  }
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Role - Used by the application running in the container
resource "aws_iam_role" "task" {
  name = "${var.name_prefix}-${var.service_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.name_prefix}-${var.service_name}-task-role"
    Service = var.service_name
  }
}

# Add any application-specific permissions here
resource "aws_iam_role_policy" "task" {
  name = "${var.name_prefix}-${var.service_name}-task-policy"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}
