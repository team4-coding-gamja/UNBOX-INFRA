
# [Fix] Redis Security Group Rule (Best Practice)
# Using explicit Node Security Group ID instead of VPC CIDR.
resource "aws_security_group_rule" "redis_ingress_from_eks_node" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = module.security_group.redis_sg_id
  source_security_group_id = module.security_group.eks_node_sg_id
  description              = "Allow EKS Worker Nodes to access Redis"
}
