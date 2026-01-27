# 1. Redis 서브넷 그룹 (RDS와 마찬가지로 Private 서브넷에 배치)
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.project_name}-${var.env}-redis-sng"
  subnet_ids = var.private_subnet_ids
}

# 2. Redis 복제 그룹 (Replication Group)
resource "aws_elasticache_replication_group" "this" {
  replication_group_id          = "${var.project_name}-${var.env}-redis"
  description = "Redis cluster for ${var.project_name}"
  
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.env == "prod" ? "cache.t4g.small" :"cache.t4g.micro" # DB와 마찬가지로 작고 소중한 가성비 사양
  port                 = 6379
  
  parameter_group_name = "default.redis7"
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [var.redis_sg_id]

  # [환경별 로직]
  # Prod: 장애 조치를 위해 2개의 노드(Primary, Replica) 생성
  # Dev: 비용 절감을 위해 1개의 노드만 생성
  automatic_failover_enabled = var.env == "prod" ? true : false
  num_cache_clusters         = var.env == "prod" ? 2 : 1
  multi_az_enabled           = var.env == "prod" ? true : false

  # 데이터 암호화 (KMS 활용)
  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  transit_encryption_enabled = true # 전송 중 암호화 (보안 권장)
  auth_token                 = var.auth_token
  tags = { Name = "${var.project_name}-${var.env}-redis" }
}