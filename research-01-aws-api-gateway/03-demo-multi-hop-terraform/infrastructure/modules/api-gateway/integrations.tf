# ==============================================================================
# API Gateway Integrations
# HTTP_PROXY integration with VPC Link to ALB
# ==============================================================================

# ------------------------------------------------------------------------------
# Single Integration to ALB (shared by all routes)
# The path rewriting happens at the route level
# ------------------------------------------------------------------------------
resource "aws_apigatewayv2_integration" "alb" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.alb_listener_arn

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.main.id

  # Use payload format version 1.0 for HTTP_PROXY
  payload_format_version = "1.0"

  # Timeout configuration
  timeout_milliseconds = 30000

  description = "Integration with internal ALB via VPC Link"
}
