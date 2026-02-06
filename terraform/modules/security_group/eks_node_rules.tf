
resource "aws_security_group_rule" "eks_node_ingress_self" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_node.id
  source_security_group_id = aws_security_group.eks_node.id
  description              = "Allow Node-to-Node communication (DNS, Pod-to-Pod)"
}
