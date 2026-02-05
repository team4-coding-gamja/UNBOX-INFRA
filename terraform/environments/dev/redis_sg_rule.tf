# [Fix] Redis Security Group Rule (Updated)
# Using VPC CIDR instead of specific SG ID to ensure all EKS nodes (and future resources in VPC) can access Redis.
resource "aws_security_group_rule" "redis_ingress_from_vpc" {
  type              = "ingress"
  from_port         = 6379
  to_port           = 6379
  protocol          = "tcp"
  security_group_id = module.security_group.redis_sg_id
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  description       = "Allow Internal VPC access to Redis"
}
