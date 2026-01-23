# 1. 공통 시크릿 (JWT Key 등)
resource "aws_ssm_parameter" "common_secrets" {
  # 리스트 순회
  for_each = toset(["JWT_SECRET", "API_ENCRYPTION_KEY"])

  name   = "/${var.project_name}/${var.env}/common/${each.value}"
  type   = "SecureString"
  # [수정] 서비스별 비번이 아닌, rds_password를 재활용하거나 전용 비번을 생성해야 합니다.
  value  = random_password.rds_password.result 
  key_id = var.kms_key_arn

  lifecycle { ignore_changes = [value] }
}

# 2. 서비스별 시크릿 (DB 비번 등)
resource "aws_ssm_parameter" "service_secrets" {
  # dev 환경일 때만 생성
  for_each = var.env == "dev" ? var.service_config : {}

  name   = "/${var.project_name}/${var.env}/${each.key}/DB_PASSWORD"
  type   = "SecureString"
  # [정상] 서비스별 비번 맵에서 해당 서비스의 비번을 가져옴
  value  = random_password.service_db_passwords[each.key].result
  key_id = var.kms_key_arn

  lifecycle { ignore_changes = [value] }
}

# 3. Prod용 Secrets Manager (RDS 마스터 비번)
resource "aws_secretsmanager_secret" "rds_password" {
  count = var.env == "prod" ? 1 : 0
  name  = "${var.project_name}/${var.env}/rds/admin-password"
}

resource "aws_secretsmanager_secret_version" "rds_password_val" {
  count         = var.env == "prod" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.rds_password[0].id
  # [정상] 단일 마스터 비번 사용
  secret_string = random_password.rds_password.result
}

# ---------------------------------------------------------
# Password 리소스들 (반드시 같은 모듈 내부에 위치)
# ---------------------------------------------------------
resource "random_password" "service_db_passwords" {
  for_each = var.service_config
  length   = 16
  special  = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "rds_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}