# modules/eks/helm_eso.tf

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  version          = "0.9.13" # Pin a stable version

  # 중요: Service Account에 IAM Role ARN 어노테이션 추가
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.eso.arn
  }

  set {
    name  = "serviceAccount.name"
    value = "external-secrets"
  }

  # Fargate 사용 시 호환성을 위해 추가 설정 가능 (현재는 Node Group 사용 중이라 기본값 무관)
}
