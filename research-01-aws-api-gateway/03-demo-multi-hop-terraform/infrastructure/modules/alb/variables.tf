variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ALB"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for ALB"
  type        = list(string)
}

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
}
