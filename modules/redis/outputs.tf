output "redis_primary_endpoint" {
  description = "Redis 쓰기용 엔드포인트"
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Redis 읽기용 엔드포인트"
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}