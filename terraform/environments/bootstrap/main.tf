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


# # 1. 환경별 KMS 마스터 키 생성
# resource "aws_kms_key" "this" {
#   # 리스트를 set으로 변환하여 순회
#   for_each = toset(var.env)

#   description             = "${var.project_name}-${each.key}-main-kms"
#   deletion_window_in_days = 7
#   enable_key_rotation     = true

#   # [보안] 키 정책: CloudWatch Logs 등이 이 키를 쓸 수 있게 허용
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "Enable IAM User Permissions"
#         Effect = "Allow"
#         Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
#         Action   = "kms:*"
#         Resource = "*"
#       },
#       {
#         Sid    = "Allow CloudWatch Logs to use the key"
#         Effect = "Allow"
#         Principal = { Service = "logs.ap-northeast-2.amazonaws.com" }
#         Action = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
#         Resource = "*"
#       }
#     ]
#   })

#   tags = {
#     Name        = "${var.project_name}-${each.key}-kms"
#     Environment = each.key
#   }
# }

# # 2. 환경별 별칭(Alias) 생성
# resource "aws_kms_alias" "this" {
#   for_each = toset(var.env)

#   # alias/unbox/dev/main-key 형식
#   name          = "alias/${var.project_name}/${each.key}/main-key"
#   target_key_id = aws_kms_key.this[each.key].key_id
# }

# # 3. 결과 출력 (Map 형태)
# output "kms_key_arns" {
#   description = "환경별 KMS ARN 맵"
#   value       = { for k, v in aws_kms_key.this : k => v.arn }
# }
data "aws_kms_alias" "dev_kms" {
  # 기존에 콘솔에서 만드신 별칭 이름 (alias/unbox/dev/main-key 등)
  name = "alias/unbox/dev/main-key"
}
# --- 데이터 및 변수 ---
data "aws_caller_identity" "current" {}

variable "project_name" {
  default = "unbox"
}

variable "env" {
  type    = list(string)
  default = ["dev", "prod"]
}

locals {
  service_config = {
    "user"    = 80
    "product" = 80
    "trade"   = 80
    "order"   = 80
    "payment" = 80
  }

  # [핵심] 환경(dev, prod)과 서비스(user, product 등)를 조합한 리스트 생성
  ecr_map = {
    for pair in setproduct(var.env, keys(local.service_config)) :
    "${pair[0]}-${pair[1]}" => {
      env     = pair[0]
      service = pair[1]
    }
  }
}

resource "aws_ecr_repository" "services" {
  for_each = local.ecr_map

  # 결과: unbox-dev-user-repo, unbox-prod-user-repo 등이 생성됨
  name                 = "${var.project_name}-${each.value.env}-${each.value.service}-repo"
  image_tag_mutability = each.value.env == "prod" ? "IMMUTABLE" : "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-${each.value.env}-${each.value.service}-repo"
    Environment = each.value.env
  }
}


# ---------------------------------------------------------
# 1. 환경별 x 서비스별 조합 데이터 생성 (Locals)
# ---------------------------------------------------------
locals {
  # 환경(dev, prod)과 서비스(user, product 등)를 조합하여 시크릿 생성용 맵 생성
  secret_map = {
    for pair in setproduct(var.env, keys(local.service_config)) :
    "${pair[0]}-${pair[1]}" => {
      env     = pair[0]
      service = pair[1]
    }
  }
}

# ---------------------------------------------------------
# 2. 랜덤 패스워드 생성 (모든 환경 x 모든 서비스)
# ---------------------------------------------------------
resource "random_password" "db_password" {
  for_each = local.secret_map
  length   = 16
  special  = true
  override_special = "!#$%&*()-_=+[]{}<>" 
}

resource "random_password" "redis_password" {
  for_each = toset(var.env) # 환경별로(dev, prod) 하나씩 생성
  length   = 20
  special  = false 
}

# ---------------------------------------------------------
# 3. Secrets Manager 생성 (Prod 환경만 생성하도록 필터링)
# ---------------------------------------------------------

# 3-1. 서비스별 DB 비밀번호
resource "aws_secretsmanager_secret" "db_password" {
  # 'prod' 환경인 조합만 골라서 생성
  for_each = { for k, v in local.secret_map : k => v if v.env == "prod" }

  name        = "${var.project_name}/${each.value.env}/${each.value.service}/db-password"
  description = "Database password for ${each.value.service} in ${each.value.env}"
  kms_key_id = data.aws_kms_alias.dev_kms.target_key_arn

  # 부트스트랩이므로 삭제 방지 및 유예기간 설정
  recovery_window_in_days = 7
  lifecycle {
    prevent_destroy = true 
    ignore_changes  = [name, description, kms_key_id]
  }
}

# resource "aws_secretsmanager_secret_version" "db_password" {
#   for_each      = { for k, v in local.secret_map : k => v if v.env == "prod" }
#   secret_id     = aws_secretsmanager_secret.db_password[each.key].id
#   secret_string = random_password.db_password[each.key].result
# }

# 3-2. Redis 비밀번호
resource "aws_secretsmanager_secret" "redis_password" {
  for_each = toset([for e in var.env : e if e == "prod"])

  name       = "${var.project_name}/${each.key}/redis_password"
  kms_key_id = data.aws_kms_alias.dev_kms.target_key_arn
  lifecycle { 
    prevent_destroy = true 
    ignore_changes  = [name, description] # 이름 변경 방지
  }
}

resource "aws_secretsmanager_secret_version" "redis_password" {
  for_each      = toset([for e in var.env : e if e == "prod"])
  secret_id     = aws_secretsmanager_secret.redis_password[each.key].id
  secret_string = random_password.redis_password[each.key].result
}