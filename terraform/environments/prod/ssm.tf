resource "aws_ssm_parameter" "rds_endpoints" {
  for_each = local.service_config

  # Dev path: /unbox/dev/rds/${each.key}/endpoint
  # Prod path: /unbox/prod/rds/${each.key}/endpoint
  name        = "/${var.project_name}/${var.env}/rds/${each.key}/endpoint"
  description = "Endpoint for RDS instance ${each.key}"
  type        = "String"

  # Prod uses individual DBs, so we access by key
  value = module.rds.db_endpoints[each.key]

  tags = {
    Environment = var.env
    Project     = var.project_name
    Service     = "rds"
  }
}

resource "aws_ssm_parameter" "redis_primary_endpoint" {
  name        = "/${var.project_name}/${var.env}/redis/primary_endpoint"
  description = "Primary endpoint for Redis"
  type        = "String"
  value       = module.redis.redis_primary_endpoint

  tags = {
    Environment = var.env
    Project     = var.project_name
    Service     = "redis"
  }
}

resource "aws_ssm_parameter" "kafka_endpoint" {
  name        = "/${var.project_name}/${var.env}/kafka/endpoint"
  description = "Internal K8s DNS endpoint for Kafka"
  type        = "String"
  # Hardcoded Kafka endpoint for Prod (Strimzi/Kali/MSK)
  value = "prod-kafka.unbox-infra.svc.cluster.local:9092"

  tags = {
    Environment = var.env
    Project     = var.project_name
    Service     = "kafka"
  }
}

# Toss Keys (Optional - if variables are populated)
resource "aws_ssm_parameter" "toss_secret_key" {
  count       = var.toss_secret_key != "" ? 1 : 0
  name        = "/${var.project_name}/${var.env}/common/TOSS_SECRET_KEY"
  description = "Toss Payments Secret Key"
  type        = "SecureString"
  value       = var.toss_secret_key

  tags = {
    Environment = var.env
    Project     = var.project_name
    Service     = "common"
  }
}

resource "aws_ssm_parameter" "toss_security_key" {
  count       = var.toss_security_key != "" ? 1 : 0
  name        = "/${var.project_name}/${var.env}/common/TOSS_SECURITY_KEY"
  description = "Toss Payments Security Key"
  type        = "SecureString"
  value       = var.toss_security_key

  tags = {
    Environment = var.env
    Project     = var.project_name
    Service     = "common"
  }
}
