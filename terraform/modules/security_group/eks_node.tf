
resource "aws_security_group" "eks_node" {
  name   = "${var.project_name}-${var.env}-eks-node-sg"
  vpc_id = var.vpc_id
  tags   = { Name = "${var.project_name}-${var.env}-eks-node-sg" }
}

resource "aws_security_group_rule" "eks_node_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_node.id
}
