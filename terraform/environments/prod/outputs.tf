output "alb_address" {
  value = module.alb.alb_dns_name
}

# VPC 정보
output "vpc_id" {
  value = module.vpc.vpc_id
}

# RDS 정보 (아까 5개 만드신 것)
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

output "acm_certificate_arn" {
  description = "ACM Certificate ARN for un-box.click"
  value       = var.enable_alb ? aws_acm_certificate.prod[0].arn : "ACM not created"
}
