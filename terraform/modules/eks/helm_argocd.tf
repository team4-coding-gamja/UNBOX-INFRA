# modules/eks/helm_argocd.tf

# ArgoCD 설치
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.51.0"

  # ArgoCD Server 설정 - ClusterIP로 변경 (Ingress 사용)
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  # 초기 비밀번호 설정 (선택사항)
  set {
    name  = "configs.secret.argocdServerAdminPassword"
    value = bcrypt(var.argocd_admin_password)
  }

  # Insecure mode (HTTPS 없이 사용, 개발 환경용)
  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  # Ingress 활성화
  set {
    name  = "server.ingress.enabled"
    value = "true"
  }

  # Ingress Class - AWS Load Balancer Controller
  set {
    name  = "server.ingress.ingressClassName"
    value = "alb"
  }

  # Ingress Annotations - ALB 설정
  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\\\"HTTP\\\": 80}]"
  }

  # Ingress Host (선택사항)
  set {
    name  = "server.ingress.hosts[0]"
    value = "argocd.${var.env}.unbox.com"
  }

  depends_on = [
    aws_eks_node_group.main
  ]
}

# Argo Rollouts 설치
resource "helm_release" "argo_rollouts" {
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = "argo-rollouts"
  create_namespace = true
  version          = "2.32.0"

  # Dashboard 활성화
  set {
    name  = "dashboard.enabled"
    value = "true"
  }

  depends_on = [
    aws_eks_node_group.main
  ]
}
