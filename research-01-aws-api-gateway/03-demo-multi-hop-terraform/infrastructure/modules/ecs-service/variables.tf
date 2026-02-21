variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "service_name" {
  description = "Service name"
  type        = string
}

variable "service_config" {
  description = "Service configuration"
  type = object({
    container_port    = number
    cpu               = number
    memory            = number
    desired_count     = number
    health_check_path = string
    path_prefix       = string
  })
}

variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ECS tasks"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
