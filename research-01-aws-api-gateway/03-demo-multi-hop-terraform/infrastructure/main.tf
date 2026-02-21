# ==============================================================================
# Main Terraform Configuration
# Multi-Hop Path Mapping Demo: API Gateway → ALB → ECS Fargate
# ==============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ------------------------------------------------------------------------------
# VPC Module
# ------------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

# ------------------------------------------------------------------------------
# Security Groups Module
# ------------------------------------------------------------------------------
module "security_groups" {
  source = "./modules/security-groups"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = var.vpc_cidr
}

# ------------------------------------------------------------------------------
# ECR Repositories
# ------------------------------------------------------------------------------
module "ecr" {
  source   = "./modules/ecr"
  for_each = var.services

  name_prefix  = local.name_prefix
  service_name = each.key
}

# ------------------------------------------------------------------------------
# ECS Cluster
# ------------------------------------------------------------------------------
module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  name_prefix = local.name_prefix
}

# ------------------------------------------------------------------------------
# Application Load Balancer
# ------------------------------------------------------------------------------
module "alb" {
  source = "./modules/alb"

  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.alb_security_group_id]
  services           = var.services
}

# ------------------------------------------------------------------------------
# ECS Services
# ------------------------------------------------------------------------------
module "ecs_service" {
  source   = "./modules/ecs-service"
  for_each = var.services

  name_prefix       = local.name_prefix
  service_name      = each.key
  service_config    = each.value
  cluster_id        = module.ecs_cluster.cluster_id
  cluster_name      = module.ecs_cluster.cluster_name
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = module.security_groups.ecs_security_group_id
  target_group_arn  = module.alb.target_group_arns[each.key]
  ecr_repository_url = module.ecr[each.key].repository_url
  aws_region        = var.aws_region
}

# ------------------------------------------------------------------------------
# API Gateway (HTTP API)
# ------------------------------------------------------------------------------
module "api_gateway" {
  source = "./modules/api-gateway"

  name_prefix          = local.name_prefix
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = module.vpc.private_subnet_ids
  security_group_ids   = [module.security_groups.vpc_link_security_group_id]
  alb_listener_arn     = module.alb.listener_arn
  api_routes           = var.api_routes
}
