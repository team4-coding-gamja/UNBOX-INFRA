# modules/eks/helm_argocd.tf

# ArgoCD 설치
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.51.0"

  # ArgoCD Server 설정
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
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
