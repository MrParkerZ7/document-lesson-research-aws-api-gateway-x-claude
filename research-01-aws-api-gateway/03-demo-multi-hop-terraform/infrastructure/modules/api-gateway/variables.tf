variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for VPC Link"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for VPC Link"
  type        = list(string)
}

variable "alb_listener_arn" {
  description = "ALB listener ARN for integration"
  type        = string
}

variable "api_routes" {
  description = "API route configurations"
  type = list(object({
    route_key      = string
    target_service = string
    backend_path   = string
  }))
}
