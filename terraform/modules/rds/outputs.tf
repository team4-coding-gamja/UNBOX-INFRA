output "db_endpoints" {
  description = "생성된 RDS 엔드포인트 맵"
  value = {
    for k, v in aws_db_instance.postgresql : k => v.endpoint
  }
}