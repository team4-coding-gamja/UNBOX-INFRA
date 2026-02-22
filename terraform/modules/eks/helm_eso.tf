# modules/eks/helm_eso.tf

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  version          = "1.3.2" # Pin a stable version

  # 중요: Service Account에 IAM Role ARN 어노테이션 추가
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.eso.arn
  }

  set {
    name  = "serviceAccount.name"
    value = "external-secrets"
  }

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "webhook.enabled"
    value = "true"
  }

  set {
    name  = "certController.enabled"
    value = "true"
  }
}
