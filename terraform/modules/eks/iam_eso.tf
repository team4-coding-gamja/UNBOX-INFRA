# modules/eks/iam_eso.tf

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
# 1. Assume Role Policy (Trust Relationship)
# Allows the 'external-secrets' Service Account in K8s to assume this IAM Role
data "aws_iam_policy_document" "eso_assume_role" {
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
      values   = ["system:serviceaccount:external-secrets:external-secrets"] # Namespace:ServiceAccountName
    }
  }
}

# 2. IAM Role
resource "aws_iam_role" "eso" {
  name               = "${var.project_name}-${var.env}-eso-role"
  assume_role_policy = data.aws_iam_policy_document.eso_assume_role.json
  description        = "IAM Role for External Secrets Operator to access SSM"
}

# 3. IAM Policy (Permissions)
# Allows reading parameters from SSM and decrypting with KMS
resource "aws_iam_policy" "eso_access" {
  name        = "${var.project_name}-${var.env}-eso-policy"
  description = "Allow GetParameter and KMS Decrypt for ESO"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSSMRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParameterHistory"
        ]
        Resource = [
          "arn:aws:ssm:*:*:parameter/${var.project_name}/${var.env}/*"
        ]
      },
      {
        Sid    = "AllowKMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [var.kms_key_arn]
      },
      {
        Sid      = "AllowDescribeKey"
        Effect   = "Allow"
        Action   = ["kms:DescribeKey"]
        Resource = [var.kms_key_arn]
      },
      {
        Sid    = "AllowSecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = ["arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.env}/*"]
      }
    ]
  })
}

# 4. Attach Policy to Role
resource "aws_iam_role_policy_attachment" "eso_attach" {
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.eso_access.arn
}
