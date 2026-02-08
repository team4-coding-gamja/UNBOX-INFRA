output "alb_address" {
  value = module.alb.alb_dns_name
}

# VPC 정보
output "target_group_arns" {
  description = "Map of Target Group ARNs"
  value       = module.alb.target_group_arns
}

# RDS 정보
output "rds_endpoints" {
  value = module.rds.db_endpoints
}

# Redis 정보
output "redis_primary_endpoint" {
  value = module.redis.redis_primary_endpoint
}



output "kms_key_arn" {
  value = module.common.kms_key_arn
}
