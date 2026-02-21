variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "multi-hop-demo"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

# Service configurations
variable "services" {
  description = "Map of service configurations"
  type = map(object({
    container_port    = number
    cpu               = number
    memory            = number
    desired_count     = number
    health_check_path = string
    path_prefix       = string
  }))
  default = {
    account-service = {
      container_port    = 8080
      cpu               = 256
      memory            = 512
      desired_count     = 2
      health_check_path = "/actuator/health"
      path_prefix       = "/account-svc"
    }
    transfer-service = {
      container_port    = 8080
      cpu               = 256
      memory            = 512
      desired_count     = 2
      health_check_path = "/actuator/health"
      path_prefix       = "/transfer-svc"
    }
  }
}

# API Gateway routes configuration
variable "api_routes" {
  description = "API Gateway route configurations"
  type = list(object({
    route_key        = string
    target_service   = string
    backend_path     = string
  }))
  default = [
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
}
