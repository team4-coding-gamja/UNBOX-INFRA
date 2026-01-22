# terraform-environments/bootstrap/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # 주의: 여기서는 backend 설정을 하지 않습니다. (로컬 state 사용)
}

provider "aws" {
  region = "ap-northeast-2"
}

# 1. S3 버킷: State 파일 저장용
resource "aws_s3_bucket" "terraform_state" {
  bucket = "unbox-terraform-state-bucket-1" # 전 세계에서 중복되지 않는 이름이어야 함

  # 실수로 삭제되는 것 방지
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "global"
    Project     = "unbox"
  }
}

# 2. S3 버전 관리 (실수로 덮어썼을 때 복구용)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 3. S3 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4. S3 퍼블릭 액세스 차단 (보안 필수)
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 5. DynamoDB: State Lock용 (동시 수정 방지)
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "unbox-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Environment = "global"
    Project     = "unbox"
  }
}