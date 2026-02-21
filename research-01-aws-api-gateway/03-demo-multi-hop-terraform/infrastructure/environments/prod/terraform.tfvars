# Production Environment Configuration

aws_region   = "ap-southeast-1"
project_name = "multi-hop-demo"
environment  = "prod"

vpc_cidr           = "10.1.0.0/16"
availability_zones = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]

# Service configurations - larger for production
services = {
  account-service = {
    container_port    = 8080
    cpu               = 512
    memory            = 1024
    desired_count     = 2
    health_check_path = "/actuator/health"
    path_prefix       = "/account-svc"
  }
  transfer-service = {
    container_port    = 8080
    cpu               = 512
    memory            = 1024
    desired_count     = 2
    health_check_path = "/actuator/health"
    path_prefix       = "/transfer-svc"
  }
}

# API Gateway route configurations
api_routes = [
  {
    route_key      = "GET /accounts/{accountId}"
    target_service = "account-service"
    backend_path   = "/account-svc/api/v1/accounts/{accountId}"
  },
  {
    route_key      = "POST /accounts"
    target_service = "account-service"
    backend_path   = "/account-svc/api/v1/accounts"
  },
  {
    route_key      = "GET /accounts/{accountId}/balance"
    target_service = "account-service"
    backend_path   = "/account-svc/api/v1/accounts/{accountId}/balance"
  },
  {
    route_key      = "GET /transfers/{transferId}"
    target_service = "transfer-service"
    backend_path   = "/transfer-svc/api/v1/transfers/{transferId}"
  },
  {
    route_key      = "POST /transfers"
    target_service = "transfer-service"
    backend_path   = "/transfer-svc/api/v1/transfers"
  }
]
