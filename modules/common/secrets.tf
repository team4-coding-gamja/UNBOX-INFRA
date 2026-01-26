resource "aws_secretsmanager_secret" "db_password" {
  for_each = toset(keys(var.service_config))

  name        = "unbox/${var.env}/${each.key}/db-password"
  description = "${each.key} service database password"
  kms_key_id  = var.kms_key_arn

  tags = {
    Name = "unbox-${var.env}-${each.key}-db-password"
  }
}

resource "random_password" "db_password" {
  for_each = toset(keys(var.service_config))
  length   = 16
  special  = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 생성된 비밀번호를 시크릿에 넣어주는 리소스도 잊지 마세요!
resource "aws_secretsmanager_secret_version" "db_password" {
  for_each      = toset(keys(var.service_config))
  secret_id     = aws_secretsmanager_secret.db_password[each.key].id
  secret_string = random_password.db_password[each.key].result
}