data "aws_secretsmanager_secret" "db_password" {
  for_each = var.env == "prod" ? toset(keys(var.service_config)) : toset([])
  name     = "unbox/prod/${each.key}/db-password"
}

# 금고를 열어서 실제 값(Raw)을 가져옴
data "aws_secretsmanager_secret_version" "db_password" {
  for_each  = var.env == "prod" ? toset(keys(var.service_config)) : toset([])
  secret_id = data.aws_secretsmanager_secret.db_password[each.key].id
}

data "aws_secretsmanager_secret" "redis_password" {
  count = var.env == "prod" ? 1 : 0
  name  = "unbox/prod/redis_password" # 콘솔에 있는 이름과 정확히 일치시켜야 함
}

# 2. 금고 안의 내용물(Version)을 조회 -> 이게 있어야 secret_string을 쓸 수 있음
data "aws_secretsmanager_secret_version" "redis_password" {
  count     = var.env == "prod" ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.redis_password[0].id
}

data "aws_secretsmanager_secret" "jwt_secret" {
  count = var.env == "prod" ? 1 : 0
  # 콘솔에 있는 이름 정확히 기재 (예: unbox-prod-jwt-secret)
  name  = "${var.project_name}-${var.env}-jwt-secret" 
}