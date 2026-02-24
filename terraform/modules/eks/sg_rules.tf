# modules/eks/sg_rules.tf

# [Fix 1] Allow EKS Control Plane to access Worker Nodes (for Logs, Exec, Webhooks)
# 이 규칙은 Cluster SG(Control Plane)에서 Node SG(Worker)로 들어오는 트래픽을 허용합니다.
resource "aws_security_group_rule" "node_ingress_from_cluster" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = var.node_security_group_id
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  description              = "Allow all traffic from EKS Cluster Control Plane to Nodes"
}

# [Fix 2] Allow Worker Nodes to access EKS Control Plane (for API Server calls)
# 이 규칙은 Node SG(Worker)에서 Cluster SG(Control Plane)로 들어오는 트래픽(443)을 허용합니다.
# CoreDNS, Load Balancer Controller 등이 API 서버와 통신하기 위해 필수적입니다.
resource "aws_security_group_rule" "cluster_ingress_from_node" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  source_security_group_id = var.node_security_group_id
  description              = "Allow Worker Nodes to access EKS Control Plane API"
}
