# 1. 공통 시크릿 (JWT Key 등)
resource "aws_ssm_parameter" "common_secrets" {
  for_each = toset(["JWT_SECRET", "API_ENCRYPTION_KEY"])

  name   = "/${var.project_name}/${var.env}/common/${each.value}"
  type   = "SecureString"
  value  = "pending-manual-input"
  key_id = aws_kms_key.this.arn

  lifecycle { ignore_changes = [value] }
}

# 2. 서비스별 시크릿 (DB 비번 등)
# 각 서비스가 자기만의 비번을 가질 수 있도록 구성
resource "aws_ssm_parameter" "service_secrets" {
  for_each = var.service_config

  name   = "/${var.project_name}/${var.env}/${each.key}/DB_PASSWORD"
  type   = "SecureString"
  value  = "pending-manual-input"
  key_id = aws_kms_key.this.arn

  lifecycle { ignore_changes = [value] }
}