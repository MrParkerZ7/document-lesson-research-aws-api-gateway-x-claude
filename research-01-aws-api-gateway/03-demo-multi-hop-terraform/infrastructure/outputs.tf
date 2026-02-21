output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = module.api_gateway.api_endpoint
}

output "alb_dns_name" {
  description = "ALB DNS name (internal)"
  value       = module.alb.alb_dns_name
}

output "ecr_registry_url" {
  description = "ECR registry URL"
  value       = split("/", module.ecr["account-service"].repository_url)[0]
}

output "account_service_ecr_url" {
  description = "Account service ECR repository URL"
  value       = module.ecr["account-service"].repository_url
}

output "transfer_service_ecr_url" {
  description = "Transfer service ECR repository URL"
  value       = module.ecr["transfer-service"].repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.cluster_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# Example API calls
output "example_api_calls" {
  description = "Example API calls"
  value = <<-EOT

    # Get account by ID
    curl ${module.api_gateway.api_endpoint}/accounts/123

    # Create new account
    curl -X POST ${module.api_gateway.api_endpoint}/accounts \
      -H "Content-Type: application/json" \
      -d '{"name": "John Doe", "email": "john@example.com"}'

    # Get account balance
    curl ${module.api_gateway.api_endpoint}/accounts/123/balance

    # Create transfer
    curl -X POST ${module.api_gateway.api_endpoint}/transfers \
      -H "Content-Type: application/json" \
      -d '{"fromAccountId": "123", "toAccountId": "456", "amount": 100.00}'

  EOT
}
