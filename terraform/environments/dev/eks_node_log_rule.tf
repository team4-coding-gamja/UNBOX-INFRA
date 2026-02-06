# [Fix] Allow Control Plane (Cluster SG) to access Worker Nodes (Log/Exec)
# Port 10250 (Kubelet) and 443 (HTTPS)
resource "aws_security_group_rule" "node_ingress_from_cluster" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = module.security_group.eks_node_sg_id
  source_security_group_id = module.eks.cluster_security_group_id
  description              = "Allow Control Plane to access Kubelet (Logs/Exec)"
}

resource "aws_security_group_rule" "node_ingress_from_cluster_443" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.security_group.eks_node_sg_id
  source_security_group_id = module.eks.cluster_security_group_id
  description              = "Allow Control Plane to access Node (HTTPS)"
}

resource "aws_security_group_rule" "node_ingress_from_cluster_9443" {
  type                     = "ingress"
  from_port                = 9443
  to_port                  = 9443
  protocol                 = "tcp"
  security_group_id        = module.security_group.eks_node_sg_id
  source_security_group_id = module.eks.cluster_security_group_id
  description              = "Allow Control Plane to access LB Controller Webhook"
}

# [Fix] Allow Worker Nodes (Node SG) to access Control Plane (Cluster SG)
# Port 443 (Kubernetes API Server) - for CoreDNS, Kube-Proxy, AWS Node
resource "aws_security_group_rule" "cluster_ingress_from_node_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = module.security_group.eks_node_sg_id
  description              = "Allow Worker Nodes to access Cluster API Server"
}
