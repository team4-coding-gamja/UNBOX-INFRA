output "app_sg_ids" {
  value = { for k, v in aws_security_group.service_app : k => v.id }
}

output "rds_sg_ids" {
  value = { for k, v in aws_security_group.service_rds : k => v.id }
}

output "redis_sg_id" { value = aws_security_group.redis.id }
output "msk_sg_id"   { value = aws_security_group.msk.id }
output "nat_sg_id"   { value = var.env != "prod" ? aws_security_group.nat[0].id : null }
output "alb_sg_id"   { value = aws_security_group.alb.id }