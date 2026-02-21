# ==============================================================================
# Application Load Balancer Module
# Handles path-based routing to ECS services
# ==============================================================================

resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  internal           = true  # Internal ALB - only accessible via VPC Link
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.name_prefix}-alb"
  }
}

# ------------------------------------------------------------------------------
# HTTP Listener
# ------------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Default action returns 404 for unmatched paths
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = jsonencode({
        error   = "Not Found"
        message = "The requested path does not match any configured service"
        path    = "unknown"
      })
      status_code = "404"
    }
  }

  tags = {
    Name = "${var.name_prefix}-http-listener"
  }
}
