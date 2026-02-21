# ==============================================================================
# Target Groups for ECS Services
# ==============================================================================

resource "aws_lb_target_group" "services" {
  for_each = var.services

  name        = "${var.name_prefix}-${each.key}-tg"
  port        = each.value.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # Required for Fargate

  health_check {
    enabled             = true
    path                = each.value.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  # Deregistration delay for graceful shutdown
  deregistration_delay = 30

  tags = {
    Name    = "${var.name_prefix}-${each.key}-tg"
    Service = each.key
  }
}
