output "vpc_link_security_group_id" {
  description = "VPC Link security group ID"
  value       = aws_security_group.vpc_link.id
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ECS security group ID"
  value       = aws_security_group.ecs.id
}
