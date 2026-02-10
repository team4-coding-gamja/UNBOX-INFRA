# 1. 공통 시크릿 (JWT Secret 등)
resource "random_password" "jwt_secret_value" {
  length           = 53
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "jwt_secret" {
  name      = "/${var.project_name}/${var.env}/common/JWT_SECRET"
  type      = "SecureString"
  value     = random_password.jwt_secret_value.result
  key_id    = var.kms_key_arn
  overwrite = true
}

resource "aws_ssm_parameter" "api_encryption_key" {
  name      = "/${var.project_name}/${var.env}/common/API_ENCRYPTION_KEY"
  type      = "SecureString"
  value     = random_password.rds_password.result
  key_id    = var.kms_key_arn
  overwrite = true

  lifecycle { ignore_changes = [value] }
}

# 2. 서비스별 DB 비밀번호
resource "aws_ssm_parameter" "dev_db_passwords" {
  count = var.env == "dev" ? 1 : 0

  name = "/${var.project_name}/${var.env}/common/DB_PASSWORD"
  type = "SecureString"

  value  = random_password.dev_db_password[0].result
  key_id = var.kms_key_arn

  # lifecycle { ignore_changes = [value] }
}

# 3. Prod용 Secrets Manager (JWT Secret - 자동 로테이션용)
resource "aws_secretsmanager_secret" "jwt_secret" {
  count = var.env == "prod" ? 1 : 0

  name = "${var.project_name}-${var.env}-jwt-secret"
}

resource "aws_secretsmanager_secret_version" "jwt_secret_val" {
  count = var.env == "prod" ? 1 : 0

  secret_id     = aws_secretsmanager_secret.jwt_secret[0].id
  secret_string = random_password.rds_password.result
}

# ---------------------------------------------------------
# Password 리소스들 (반드시 같은 모듈 내부에 위치)
# ---------------------------------------------------------
resource "random_password" "service_db_passwords" {
  for_each         = var.service_config
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "dev_db_password" {

  count   = var.env == "dev" ? 1 : 0
  length  = 16
  special = false
  # override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "rds_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
resource "random_password" "redis_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "redis_password" {
  name        = "/${var.project_name}/${var.env}/redis/PASSWORD"
  description = "Password for Redis"
  type        = "SecureString"
  value       = random_password.redis_password.result
  key_id      = var.kms_key_arn

  lifecycle { ignore_changes = [value] }
}
