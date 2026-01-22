# 1. KMS 마스터 키 (우리 인프라 전용 암호화 열쇠)
resource "aws_kms_key" "this" {
  description             = "KMS key for ${var.project_name}-${var.env} infrastructure"
  deletion_window_in_days = 7   # 키 삭제 요청 시 실제 삭제까지 대기 기간 (실수 방지)
  enable_key_rotation     = true # 매년 AWS가 자동으로 키를 로테이션 (보안 권장사항)
  #IAM으로 관리할 수 있도록 IAM에 권한 주어진 사용자가 관리할 수 있도록 함
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
  tags = {
    Name = "${var.project_name}-${var.env}-kms"
  }
}

# 2. KMS 별칭 (Alias) - 복잡한 Key ID 대신 사람이 읽기 쉬운 이름을 붙입니다.
resource "aws_kms_alias" "this" {
  name          = "alias/${var.project_name}/${var.env}"
  target_key_id = aws_kms_key.this.key_id
}