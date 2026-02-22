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

  # Insecure mode (HTTPS 없이 사용, 개발 환경용)
  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  # Ingress 설정 (values 블록 사용으로 특수문자 파싱 문제 해결)
  values = [
    yamlencode({
      server = {
        ingress = {
          enabled          = true
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"     = "ip"
            "alb.ingress.kubernetes.io/listen-ports"    = var.env == "prod" ? "[{\"HTTP\": 80}, {\"HTTPS\": 443}]" : "[{\"HTTP\": 80}]"
            "alb.ingress.kubernetes.io/ssl-redirect"    = var.env == "prod" ? "443" : ""
            "alb.ingress.kubernetes.io/group.name"      = "${var.project_name}-${var.env}"
            "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn
          }
          hosts = [
            var.env == "prod" ? "argocd.un-box.click" : "argocd.${var.env}.un-box.click"
          ]
        }
      }
    })
  ]

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

# Ingress Gateway Application 자동 배포 (helm_release 사용 - plan 단계 클러스터 연결 불필요)
resource "helm_release" "ingress_gateway_app" {
  name       = "ingress-gateway-app"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"
  version    = "1.4.1"

  values = [
    yamlencode({
      applications = [{
        name      = "ingress-gateway-${var.env}"
        namespace = "argocd"
        project   = "default"
        source = {
          repoURL        = "https://github.com/team4-coding-gamja/UNBOX-INFRA.git"
          targetRevision = "HEAD"
          path           = "gitops/infra/ingress-gateway"
          helm = {
            valueFiles = ["values-${var.env}.yaml"]
          }
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "unbox-app"
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
          syncOptions = ["CreateNamespace=true"]
        }
      }]
    })
  ]

  depends_on = [
    helm_release.argocd
  ]
}
