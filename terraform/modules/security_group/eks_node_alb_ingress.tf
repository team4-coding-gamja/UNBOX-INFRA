resource "aws_security_group_rule" "node_ingress_from_alb" {
  for_each                 = var.service_config
  type                     = "ingress"
  from_port                = each.value
  to_port                  = each.value
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node.id
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow ALB to access Pods on Node (Port ${each.value})"
}
