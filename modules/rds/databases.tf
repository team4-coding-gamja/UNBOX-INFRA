# ============================================
# Dev 환경: 서비스별 데이터베이스 및 사용자 생성
# ============================================

# 1. 서비스별 데이터베이스 생성 (5개)
resource "postgresql_database" "service_dbs" {
  provider = postgresql.dev
  
  # Dev 환경에서만 생성
  for_each = var.env == "dev" ? var.service_config : {}
  
  name  = "unbox_${each.key}"
  owner = "unbox_admin"
  
  # RDS 인스턴스가 생성된 후 실행
  depends_on = [aws_db_instance.postgresql]
}

# 2. 서비스별 사용자 생성 (5명)
resource "postgresql_role" "service_users" {
  provider = postgresql.dev
  
  # Dev 환경에서만 생성
  for_each = var.env == "dev" ? var.service_config : {}
  
  name     = "unbox_${each.key}"
  login    = true
  password = var.service_db_passwords[each.key]
  
  # 데이터베이스가 생성된 후 실행
  depends_on = [postgresql_database.service_dbs]
}

# 3. 서비스별 사용자에게 해당 데이터베이스 권한 부여
resource "postgresql_grant" "service_db_ownership" {
  provider = postgresql.dev
  
  # Dev 환경에서만 생성
  for_each = var.env == "dev" ? var.service_config : {}
  
  database    = "unbox_${each.key}"
  role        = "unbox_${each.key}"
  object_type = "database"
  privileges  = ["ALL"]
  
  # 사용자가 생성된 후 실행
  depends_on = [postgresql_role.service_users]
}

# 4. 서비스별 사용자에게 스키마 권한 부여
resource "postgresql_grant" "service_schema_usage" {
  provider = postgresql.dev
  
  # Dev 환경에서만 생성
  for_each = var.env == "dev" ? var.service_config : {}
  
  database    = "unbox_${each.key}"
  role        = "unbox_${each.key}"
  schema      = "public"
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]
  
  # 데이터베이스 권한이 부여된 후 실행
  depends_on = [postgresql_grant.service_db_ownership]
}

# 5. 서비스별 사용자에게 테이블 권한 부여 (미래의 테이블 포함)
resource "postgresql_default_privileges" "service_table_privileges" {
  provider = postgresql.dev
  
  # Dev 환경에서만 생성
  for_each = var.env == "dev" ? var.service_config : {}
  
  database    = "unbox_${each.key}"
  role        = "unbox_${each.key}"
  owner       = "unbox_admin"
  schema      = "public"
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE"]
  
  # 스키마 권한이 부여된 후 실행
  depends_on = [postgresql_grant.service_schema_usage]
}
