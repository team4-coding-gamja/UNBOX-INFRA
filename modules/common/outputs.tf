####################### I AM ########################

output "ecs_task_execution_role_arn" {
  description = "ECS Task Execution Role의 ARN"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ECS Task Role의 ARN"
  value       = aws_iam_role.ecs_task_role.arn
}

####################### KMS ########################
output "kms_key_arn" {
  value = var.kms_key_arn 
}

################### Cloud Map ######################

output "cloud_map_namespace_id" {
  value = aws_service_discovery_private_dns_namespace.this.id
}

output "cloud_map_namespace_arn"{
  value = aws_service_discovery_private_dns_namespace.this.arn
}

#################### secret manager #######################
output "db_password_secret_arns" {
  value = { for k, v in aws_secretsmanager_secret.db_password : k => v.arn }
}