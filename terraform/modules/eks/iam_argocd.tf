# modules/eks/iam_argocd.tf

# 1. Assume Role Policy (Trust Relationship)
# Allows the 'argocd-repo-server' Service Account in K8s to assume this IAM Role
data "aws_iam_policy_document" "argocd_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:argocd:argocd-repo-server"] # Namespace:ServiceAccountName
    }
  }
}

# 2. IAM Role
resource "aws_iam_role" "argocd" {
  name               = "${var.project_name}-${var.env}-argocd-role"
  assume_role_policy = data.aws_iam_policy_document.argocd_assume_role.json
  description        = "IAM Role for ArgoCD to access SSM Parameter Store"
}

# 3. IAM Policy (Permissions)
# Allows reading parameters from SSM
resource "aws_iam_policy" "argocd_access" {
  name        = "${var.project_name}-${var.env}-argocd-policy"
  description = "Allow GetParameter for ArgoCD CMP"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSSMRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:ssm:*:*:parameter/${var.project_name}/${var.env}/*"
        ]
      }
    ]
  })
}

# 4. Attach Policy to Role
resource "aws_iam_role_policy_attachment" "argocd_attach" {
  role       = aws_iam_role.argocd.name
  policy_arn = aws_iam_policy.argocd_access.arn
}
