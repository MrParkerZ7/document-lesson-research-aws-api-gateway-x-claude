# ==============================================================================
# Security Groups Module
# ==============================================================================

# ------------------------------------------------------------------------------
# VPC Link Security Group
# Allows API Gateway to communicate with ALB
# ------------------------------------------------------------------------------
resource "aws_security_group" "vpc_link" {
  name        = "${var.name_prefix}-vpc-link-sg"
  description = "Security group for API Gateway VPC Link"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.name_prefix}-vpc-link-sg"
  }
}

# ------------------------------------------------------------------------------
# ALB Security Group
# Allows traffic from VPC Link
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_link.id]
    description     = "Allow HTTP from VPC Link"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow HTTP from VPC (for health checks)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.name_prefix}-alb-sg"
  }
}

# ------------------------------------------------------------------------------
# ECS Security Group
# Allows traffic from ALB
# ------------------------------------------------------------------------------
resource "aws_security_group" "ecs" {
  name        = "${var.name_prefix}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow traffic from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.name_prefix}-ecs-sg"
  }
}
