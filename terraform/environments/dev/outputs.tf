# ALB는 Ingress Controller가 생성하므로 수동으로 확인 필요
# output \"alb_address\" {
#   value = var.enable_alb ? data.aws_lb.ingress[0].dns_name : \"ALB not created yet\"
# }

# VPC 정보
# output "target_group_arns" {
#   description = "Map of Target Group ARNs"
#   value       = module.alb.target_group_arns
# }

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

output "acm_certificate_arn" {
  description = "ACM Certificate ARN for dev.un-box.click"
  value       = var.enable_alb ? aws_acm_certificate.dev[0].arn : "ACM not created"
}
