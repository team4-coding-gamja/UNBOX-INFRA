####################### I AM ########################



####################### KMS ########################
output "kms_key_arn" {
  value = var.kms_key_arn
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

output "service_db_passwords_values" {
  description = "생성된 실제 비밀번호 문자열 (Map)"
  value       = { for k, v in random_password.service_db_passwords : k => v.result }
  sensitive   = true
}

output "redis_password_arn" {
  description = "Redis 비밀번호 주소"
  value       = var.env == "prod" ? data.aws_secretsmanager_secret.redis_password[0].arn : ""
}

output "redis_password_raw" {
  value     = var.env == "prod" ? data.aws_secretsmanager_secret_version.redis_password[0].secret_string : null
  sensitive = true
}


####################### EKS Roles ########################
output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_node.arn
}

output "eks_fargate_role_arn" {
  value = aws_iam_role.eks_fargate.arn
}

output "eks_app_policy_arn" {
  description = "EKS Application Policy ARN (Secrets, Kafka, etc.)"
  value       = aws_iam_policy.eks_app_policy.arn
}
