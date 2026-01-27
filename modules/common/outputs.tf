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



# Prod용 JWT Secret ARN (ECS 모듈에서 사용)
output "jwt_secret_arn" {
  description = "JWT Secret Secrets Manager ARN (Prod 환경)"
  value       = var.env == "prod" ? aws_secretsmanager_secret.jwt_secret[0].arn : ""
  sensitive   = false
}

output "db_password_arns" {
  value = { for k, v in data.aws_secretsmanager_secret.db_password : k => v.arn }
}

output "service_db_passwords" {
  description = "Secrets Manager 금고에서 직접 꺼내온 서비스별 DB 비밀번호"
  value = {
    # random_password 대신 data 소스에서 가져온 실젯값(secret_string)을 사용
    for key, secret in data.aws_secretsmanager_secret_version.db_password : key => secret.secret_string
  }
  sensitive = true
}

output "redis_password_arn" {
  description = "Redis 비밀번호 주소"
  value = var.env == "prod" ? data.aws_secretsmanager_secret.redis_password[0].arn : ""
}

output "redis_password_raw" {
  value     = var.env == "prod" ? data.aws_secretsmanager_secret_version.redis_password[0].secret_string : null
  sensitive = true
}

