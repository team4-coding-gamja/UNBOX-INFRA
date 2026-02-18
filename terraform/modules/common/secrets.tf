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

# NOTE: Using SSM Parameter Store instead
# data "aws_secretsmanager_secret" "jwt_secret" {
#   count = var.env == "prod" ? 1 : 0
#   name = "${var.project_name}-${var.env}-jwt-secret"
# }


# ---------------------------------------------------------
# 4. Secrets Rotation Configuration
# ---------------------------------------------------------

# CloudFormation Stack으로 만든 Lambda의 ARN은 output으로 가져오거나, 
# SAR에서 지정한 function name으로 data source 조회를 해야 합니다.
data "aws_lambda_function" "rds_rotation" {
  count         = var.env == "prod" ? 1 : 0
  function_name = "${var.project_name}-${var.env}-rds-rotation-lambda"

  # Lambda 생성(SAR) 완료 후 조회
  depends_on = [aws_serverlessapplicationrepository_cloudformation_stack.rds_rotation]
}

# Rotation Rules 설정 (30일 주기)
resource "aws_secretsmanager_secret_rotation" "db_password" {
  # Prod 환경의 모든 서비스 DB에 대해 적용
  for_each            = var.env == "prod" ? data.aws_secretsmanager_secret.db_password : {}
  secret_id           = each.value.id
  rotation_lambda_arn = data.aws_lambda_function.rds_rotation[0].arn

  rotation_rules {
    automatically_after_days = 30
  }
}
