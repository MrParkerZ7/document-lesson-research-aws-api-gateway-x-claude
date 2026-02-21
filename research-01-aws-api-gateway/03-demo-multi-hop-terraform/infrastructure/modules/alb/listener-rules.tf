# ==============================================================================
# ALB Listener Rules - Path-Based Routing
#
# KEY CONCEPT: ALB routes requests based on service prefix in path
#
# /account-svc/*  → Account Service Target Group
# /transfer-svc/* → Transfer Service Target Group
#
# The path prefix is stripped before forwarding to ECS
# (via application configuration, not ALB - ALB forwards full path)
# ==============================================================================

# ------------------------------------------------------------------------------
# Account Service Rule
# Priority 10: /account-svc/* → account-service target group
# ------------------------------------------------------------------------------
resource "aws_lb_listener_rule" "account_service" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/account-svc/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services["account-service"].arn
  }

  tags = {
    Name    = "${var.name_prefix}-account-svc-rule"
    Service = "account-service"
  }
}

# ------------------------------------------------------------------------------
# Transfer Service Rule
# Priority 20: /transfer-svc/* → transfer-service target group
# ------------------------------------------------------------------------------
resource "aws_lb_listener_rule" "transfer_service" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  condition {
    path_pattern {
      values = ["/transfer-svc/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services["transfer-service"].arn
  }

  tags = {
    Name    = "${var.name_prefix}-transfer-svc-rule"
    Service = "transfer-service"
  }
}

# ==============================================================================
# NOTE: Path Stripping
#
# ALB does NOT strip the path prefix - it forwards the full path.
# The Spring Boot application is configured with a context-path to handle this.
#
# Option 1: Application handles full path
#   - Spring Boot context-path: /account-svc
#   - Controller mapping: /api/v1/accounts/{id}
#   - Full path: /account-svc/api/v1/accounts/{id}
#
# Option 2: Use ALB path rewrite (requires additional configuration)
#   - Use redirect action with path rewrite
#   - More complex, but gives cleaner paths to application
#
# This demo uses Option 1 for simplicity
# ==============================================================================
