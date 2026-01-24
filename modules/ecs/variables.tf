# --- 공통 프로젝트 정보 ---
variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "env" {
  description = "운영 환경 (dev, prod)"
  type        = string
}

# --- 서비스 구성 정보 ---
variable "service_names" {
  description = "구축할 마이크로서비스 목록"
  type        = list(string)
  default     = ["order", "payment", "product", "trade", "user"]
}

variable "service_config" {
  description = "각 서비스별 컨테이너 포트 매핑"
  type        = map(number)
}

# --- 네트워크 및 보안 그룹 (인프라 모듈에서 전달받음) ---
variable "app_subnet_ids" {
  description = "애플리케이션이 배치될 프라이빗 서브넷 ID 리스트"
  type        = list(string)
}

variable "ecs_sg_id" {
  description = "ECS Task에 적용할 보안 그룹 ID"
  type        = string
}

# --- 로드 밸런서 연결 ---
variable "target_group_arns" {
  description = "ALB 리스너 규칙에서 연결할 타겟 그룹 ARN 맵"
  type        = map(string)
}

# --- 외부 연동 (MSK, IAM, KMS) ---
variable "msk_bootstrap_brokers" {
  description = "MSK 클러스터 접속 주소 (IAM 인증용)"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ECR 이미지 풀링 및 SSM/KMS 접근을 위한 실행 역할 ARN"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "MSK 전송 등 비즈니스 로직 수행을 위한 태스크 역할 ARN"
  type        = string
}

variable "aws_region" {
  description = "AWS 리전"
  type=string
}

variable "account_id" {
  description = "AWS 계정 번호"
  type        = string
}

variable "cloud_map_namespace_arn" {
  description = "Cloud Map Namespace ARN"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS 키 ARN"
  type        = string
}

# 1. RDS 및 Redis 연결 정보
variable "rds_endpoints" {
  description = "각 서비스별 RDS 엔드포인트 맵 (예: {user = 'user-db.xxx.rds.amazonaws.com:5432'})"
  type        = map(string)
}

variable "redis_endpoint" {
  description = "Redis 클러스터 primary 엔드포인트 (예: 'redis.xxx.cache.amazonaws.com:6379')"
  type        = string
}

# 2. Secrets Manager ARN
variable "jwt_secret_arn" {
  description = "JWT Secret의 Secrets Manager ARN"
  type        = string
}

variable "db_password_secret_arns" {
  description = "각 서비스별 DB 비밀번호 Secret ARN 맵"
  type        = map(string)
}

# 3. 컨테이너 설정 옵션
variable "container_name_suffix" {
  description = "컨테이너 이름에 -service suffix 추가 여부 (예: user → user-service)"
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "컨테이너 health check 경로"
  type        = string
  default     = "/actuator/health"
}
