resource "aws_ssm_parameter" "rds_endpoints" {
  for_each = local.service_config

  name        = "/${var.project_name}/${var.env}/rds/${each.key}/endpoint"
  description = "Endpoint for RDS instance ${each.key}"
  type        = "String"
  value       = "jdbc:postgresql://${module.rds.db_endpoints["common"]}/unbox_db"

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

resource "aws_ssm_parameter" "redis_reader_endpoint" {
  name        = "/${var.project_name}/${var.env}/redis/reader_endpoint"
  description = "Reader endpoint for Redis"
  type        = "String"
  value       = module.redis.redis_reader_endpoint

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
  value       = "kafka.unbox-infra.svc.cluster.local:9092"

  tags = {
    Environment = var.env
    Project     = var.project_name
    Service     = "kafka"
  }
}

resource "aws_ssm_parameter" "target_group_arns" {
  for_each = local.service_config

  name        = "/${var.project_name}/${var.env}/tg/${each.key}/arn"
  description = "Target Group ARN for ${each.key} service"
  type        = "String"
  value       = module.alb.target_group_arns[each.key]

  tags = {
    Environment = var.env
    Project     = var.project_name
    Service     = each.key
  }
}

resource "aws_ssm_parameter" "toss_secret_key" {
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
