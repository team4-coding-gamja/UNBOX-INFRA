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

################### Passwords ######################

# 서비스별 DB 비밀번호 (RDS 모듈에서 사용)
output "service_db_passwords" {
  description = "서비스별 DB 비밀번호"
  value = {
    for key, pwd in random_password.service_db_passwords : key => pwd.result
  }
  sensitive = true
}

# Prod용 JWT Secret ARN (ECS 모듈에서 사용)
output "jwt_secret_arn" {
  description = "JWT Secret Secrets Manager ARN (Prod 환경)"
  value       = var.env == "prod" ? aws_secretsmanager_secret.jwt_secret[0].arn : ""
  sensitive   = false
}
