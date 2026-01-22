# 1. 생성할 버킷 용도 정의
locals {
  bucket_types = ["logs", "artifacts", "data","cloudtrail"]
}
data "aws_caller_identity" "current" {}

# 2. S3 버킷 생성
resource "aws_s3_bucket" "this" {
  for_each = toset(local.bucket_types)

  # 버킷 이름: 프로젝트-환경-용도-리전약어 (전 세계 중복 불가 방지)
  bucket = "${var.project_name}-${var.env}-${each.key}-${var.region_suffix}"

  # 개발 환경에서는 삭제 시 내용물이 있어도 강제 삭제 허용 (운영은 false 권장)
  force_destroy = var.env == "prod" ? false : true

  tags = {
    Name = "${var.project_name}-${var.env}-${each.key}-s3"
  }
}

# 3. 퍼블릭 액세스 차단 (보안 필수)
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = aws_s3_bucket.this

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 4. 버전 관리 활성화 (파일 복구용)
resource "aws_s3_bucket_versioning" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_policy" {
  bucket = aws_s3_bucket.this["cloudtrail"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.this["cloudtrail"].arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:PutObject"
        # 이제 여기서 data.aws_caller_identity.current를 인식할 수 있습니다.
        Resource = "${aws_s3_bucket.this["cloudtrail"].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}