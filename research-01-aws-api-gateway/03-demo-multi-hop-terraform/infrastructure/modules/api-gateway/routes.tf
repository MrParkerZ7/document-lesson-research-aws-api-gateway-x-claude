# ==============================================================================
# API Gateway Routes with Path Transformation
#
# KEY CONCEPT: This is where the path rewriting magic happens!
#
# External Path (clean API) → Internal Path (with service prefix for ALB routing)
#
# Example:
#   GET /accounts/123 → /account-svc/api/v1/accounts/123
#   POST /transfers   → /transfer-svc/api/v1/transfers
# ==============================================================================

# ------------------------------------------------------------------------------
# Dynamic Route Creation with Path Rewriting
# ------------------------------------------------------------------------------
resource "aws_apigatewayv2_route" "routes" {
  for_each = { for route in var.api_routes : route.route_key => route }

  api_id    = aws_apigatewayv2_api.main.id
  route_key = each.value.route_key

  target = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# ------------------------------------------------------------------------------
# Route Response (for request parameter mapping)
# Path transformation is done via request parameter overrides
# ------------------------------------------------------------------------------

# Account Routes
resource "aws_apigatewayv2_route" "get_account" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /accounts/{accountId}"
  target    = "integrations/${aws_apigatewayv2_integration.alb_account_get.id}"
}

resource "aws_apigatewayv2_route" "create_account" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /accounts"
  target    = "integrations/${aws_apigatewayv2_integration.alb_account_create.id}"
}

resource "aws_apigatewayv2_route" "get_account_balance" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /accounts/{accountId}/balance"
  target    = "integrations/${aws_apigatewayv2_integration.alb_account_balance.id}"
}

# Transfer Routes
resource "aws_apigatewayv2_route" "get_transfer" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /transfers/{transferId}"
  target    = "integrations/${aws_apigatewayv2_integration.alb_transfer_get.id}"
}

resource "aws_apigatewayv2_route" "create_transfer" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /transfers"
  target    = "integrations/${aws_apigatewayv2_integration.alb_transfer_create.id}"
}

# ==============================================================================
# Integrations with Path Parameter Mapping
# Each integration specifies the path transformation to ALB
# ==============================================================================

# Account Service Integrations
resource "aws_apigatewayv2_integration" "alb_account_get" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "GET"
  integration_uri    = var.alb_listener_arn

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.main.id

  payload_format_version = "1.0"
  timeout_milliseconds   = 30000

  # PATH REWRITING: /accounts/{accountId} → /account-svc/api/v1/accounts/{accountId}
  request_parameters = {
    "overwrite:path" = "/account-svc/api/v1/accounts/$request.path.accountId"
  }

  description = "Get account by ID - transforms path for ALB routing"
}

resource "aws_apigatewayv2_integration" "alb_account_create" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "POST"
  integration_uri    = var.alb_listener_arn

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.main.id

  payload_format_version = "1.0"
  timeout_milliseconds   = 30000

  # PATH REWRITING: /accounts → /account-svc/api/v1/accounts
  request_parameters = {
    "overwrite:path" = "/account-svc/api/v1/accounts"
  }

  description = "Create account - transforms path for ALB routing"
}

resource "aws_apigatewayv2_integration" "alb_account_balance" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "GET"
  integration_uri    = var.alb_listener_arn

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.main.id

  payload_format_version = "1.0"
  timeout_milliseconds   = 30000

  # PATH REWRITING: /accounts/{accountId}/balance → /account-svc/api/v1/accounts/{accountId}/balance
  request_parameters = {
    "overwrite:path" = "/account-svc/api/v1/accounts/$request.path.accountId/balance"
  }

  description = "Get account balance - transforms path for ALB routing"
}

# Transfer Service Integrations
resource "aws_apigatewayv2_integration" "alb_transfer_get" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "GET"
  integration_uri    = var.alb_listener_arn

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.main.id

  payload_format_version = "1.0"
  timeout_milliseconds   = 30000

  # PATH REWRITING: /transfers/{transferId} → /transfer-svc/api/v1/transfers/{transferId}
  request_parameters = {
    "overwrite:path" = "/transfer-svc/api/v1/transfers/$request.path.transferId"
  }

  description = "Get transfer by ID - transforms path for ALB routing"
}

resource "aws_apigatewayv2_integration" "alb_transfer_create" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "POST"
  integration_uri    = var.alb_listener_arn

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.main.id

  payload_format_version = "1.0"
  timeout_milliseconds   = 30000

  # PATH REWRITING: /transfers → /transfer-svc/api/v1/transfers
  request_parameters = {
    "overwrite:path" = "/transfer-svc/api/v1/transfers"
  }

  description = "Create transfer - transforms path for ALB routing"
}
