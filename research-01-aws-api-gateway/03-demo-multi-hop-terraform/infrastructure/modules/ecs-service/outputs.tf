output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "service_id" {
  description = "ECS service ID"
  value       = aws_ecs_service.main.id
}

output "task_definition_arn" {
  description = "Task definition ARN"
  value       = aws_ecs_task_definition.main.arn
}
