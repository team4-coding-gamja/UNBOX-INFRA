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
# MSK 정보 (중요!)
output "msk_bootstrap_brokers" {
  value = module.msk.bootstrap_brokers
}
output "kms_key_arn" {
  value = module.common.kms_key_arn
}

output "ecs_task_execution_role_arn" {
  value = module.common.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  value = module.common.ecs_task_role_arn
}