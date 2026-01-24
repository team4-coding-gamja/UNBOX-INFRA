# PostgreSQL Provider 설정
# Dev 환경에서만 사용 (공유 RDS 1개)
provider "postgresql" {
  alias = "dev"
  
  # Dev 환경에서만 활성화
  host     = var.env == "dev" ? aws_db_instance.postgresql["common"].address : null
  port     = 5432
  username = "unbox_admin"
  password = var.db_password
  sslmode  = "require"
  
  connect_timeout = 15
  superuser       = false
}
