variable "project_name" {
  description = "프로젝트 이름 (리소스 명칭용)"
  type        = string
}

variable "env" {
  description = "배포 환경 (dev 또는 prod)"
  type        = string
}

# 1. 네트워크 관련
variable "private_subnet_ids" {
  description = "Redis가 위치할 Private 서브넷 ID 리스트"
  type        = list(string)
}

# 2. 보안 관련
variable "redis_sg_id" {
  description = "보안 그룹 모듈에서 생성한 Redis용 SG ID"
  type        = string
}

variable "kms_key_arn" {
  description = "데이터 암호화에 사용할 KMS 마스터 키 ARN"
  type        = string
}

# 3. 사양 관련 (선택 사항이나 관리상 편리함)
variable "node_type" {
  description = "Redis 인스턴스 타입"
  type        = string
  default     = "cache.t4g.micro"
}