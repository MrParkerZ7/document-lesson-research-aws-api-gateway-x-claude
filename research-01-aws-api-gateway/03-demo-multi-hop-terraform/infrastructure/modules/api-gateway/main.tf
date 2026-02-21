# ==============================================================================
# API Gateway HTTP API Module
# Key component for path rewriting in multi-hop architecture
# ==============================================================================

# ------------------------------------------------------------------------------
# HTTP API
# ------------------------------------------------------------------------------
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"
  description   = "HTTP API for multi-hop path mapping demo"

  cors_configuration {
    allow_headers = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_origins = ["*"]
    max_age       = 300
  }

  tags = {
    Name = "${var.name_prefix}-api"
  }
}

# ------------------------------------------------------------------------------
# VPC Link - Enables private integration with ALB
# ------------------------------------------------------------------------------
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "${var.name_prefix}-vpc-link"
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  tags = {
    Name = "${var.name_prefix}-vpc-link"
  }
}

# ------------------------------------------------------------------------------
# Default Stage with Auto Deploy
# ------------------------------------------------------------------------------
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
      # Path transformation tracking
      path           = "$context.path"
    })
  }

  tags = {
    Name = "${var.name_prefix}-stage"
  }
}

# ------------------------------------------------------------------------------
# CloudWatch Log Group for API Gateway
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.name_prefix}-api"
  retention_in_days = 7

  tags = {
    Name = "${var.name_prefix}-api-logs"
  }
}
