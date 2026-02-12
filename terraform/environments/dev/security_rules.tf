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

resource "aws_security_group_rule" "node_ingress_from_cluster_8443" {
  type                     = "ingress"
  from_port                = 8443
  to_port                  = 8443
  protocol                 = "tcp"
  security_group_id        = module.security_group.eks_node_sg_id
  source_security_group_id = module.eks.cluster_security_group_id
  description              = "Allow Control Plane to access Linkerd Proxy Injector Webhook"
}

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

# [Fix] Grafana Ingress (ALB -> Node:3000)
resource "aws_security_group_rule" "grafana_ingress_from_alb" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = module.security_group.eks_node_sg_id
  source_security_group_id = module.security_group.alb_sg_id
  description              = "Allow Inbound from ALB to Grafana (Port 3000)"
}

resource "aws_security_group_rule" "grafana_egress_from_alb" {
  type                     = "egress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = module.security_group.alb_sg_id
  source_security_group_id = module.security_group.eks_node_sg_id
  description              = "Allow Outbound from ALB to Grafana (Port 3000)"
}
