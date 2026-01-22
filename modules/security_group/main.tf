locals {
  service_config = {
    "user" = 80
    "product"    = 80
    "trade"   = 80
    "order"   = 80
    "payment" = 80
  }
}

# 1. 보안 그룹 본체 (껍데기) 생성
resource "aws_security_group" "alb" {
  name   = "${var.project_name}-${var.env}-alb-sg"
  vpc_id = var.vpc_id
  tags   = { Name = "${var.project_name}-${var.env}-alb-sg" }
}

resource "aws_security_group" "service_app" {
  for_each = local.service_config
  name     = "${var.project_name}-${var.env}-${each.key}-app-sg"
  vpc_id   = var.vpc_id
  tags     = { Name = "${var.project_name}-${var.env}-${each.key}-app-sg" }
}

resource "aws_security_group" "service_rds" {
  for_each = local.service_config
  name     = "${var.project_name}-${var.env}-${each.key}-rds-sg"
  vpc_id   = var.vpc_id
  tags     = { Name = "${var.project_name}-${var.env}-${each.key}-rds-sg" }
}

resource "aws_security_group" "redis" {
  name   = "${var.project_name}-${var.env}-redis-sg"
  vpc_id = var.vpc_id
}

resource "aws_security_group" "msk" {
  name   = "${var.project_name}-${var.env}-msk-sg"
  vpc_id = var.vpc_id
}

# 누락되었던 NAT SG 추가
resource "aws_security_group" "nat" {
  count  = var.env != "prod" ? 1 : 0
  name   = "${var.project_name}-${var.env}-nat-sg"
  vpc_id = var.vpc_id
  tags   = { Name = "${var.project_name}-${var.env}-nat-sg" }
}

# 2. 세부 규칙 (Rule) 연결

# ALB Inbound (80, 443)
resource "aws_security_group_rule" "alb_ingress_80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# App Inbound (From ALB)
resource "aws_security_group_rule" "app_ingress_from_alb" {
  for_each                 = local.service_config
  type                     = "ingress"
  from_port                = each.value
  to_port                  = each.value
  protocol                 = "tcp"
  security_group_id        = aws_security_group.service_app[each.key].id
  source_security_group_id = aws_security_group.alb.id
}

# App Inbound (Self - Envoy)
resource "aws_security_group_rule" "app_ingress_self" {
  for_each          = local.service_config
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.service_app[each.key].id
}

# RDS Inbound (From App)
resource "aws_security_group_rule" "rds_ingress_from_app" {
  for_each                 = local.service_config
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.service_rds[each.key].id
  source_security_group_id = aws_security_group.service_app[each.key].id
}

# Redis Inbound (From App)
resource "aws_security_group_rule" "redis_ingress_from_app" {
  for_each                 = local.service_config
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = aws_security_group.service_app[each.key].id
}

# MSK Inbound (From App)
resource "aws_security_group_rule" "msk_ingress_from_app" {
  for_each                 = local.service_config
  type                     = "ingress"
  from_port                = 9094
  to_port                  = 9094
  protocol                 = "tcp"
  security_group_id        = aws_security_group.msk.id
  source_security_group_id = aws_security_group.service_app[each.key].id
}

# NAT Inbound (From VPC)
resource "aws_security_group_rule" "nat_ingress_vpc" {
  count             = var.env != "prod" ? 1 : 0
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["10.1.0.0/16"]
  security_group_id = aws_security_group.nat[0].id
}

# --- Outbound Rules ---

# 1. App -> RDS (5432)
resource "aws_security_group_rule" "app_egress_to_rds" {
  for_each                 = local.service_config
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.service_app[each.key].id
  source_security_group_id = aws_security_group.service_rds[each.key].id
}

# 2. App -> Redis (6379)
resource "aws_security_group_rule" "app_egress_to_redis" {
  for_each                 = local.service_config
  type                     = "egress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.service_app[each.key].id
  source_security_group_id = aws_security_group.redis.id
}

# 3. App -> MSK (9094)
resource "aws_security_group_rule" "app_egress_to_msk" {
  for_each                 = local.service_config
  type                     = "egress"
  from_port                = 9094
  to_port                  = 9094
  protocol                 = "tcp"
  security_group_id        = aws_security_group.service_app[each.key].id
  source_security_group_id = aws_security_group.msk.id
}

# 4. App -> 인터넷 (HTTPS 443)
# Secrets Manager, KMS, ECR 등을 위해 외부 443은 열어두어야 합니다.
resource "aws_security_group_rule" "app_egress_https" {
  for_each          = local.service_config
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.service_app[each.key].id
}

# NAT Outbound (To Internet) -> DEV 환경에서는 NAT instance 만들거라서 필요함!
resource "aws_security_group_rule" "nat_egress_all" {
  count             = var.env != "prod" ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nat[0].id
}

#ALB -> Service
resource "aws_security_group_rule" "alb_egress_to_app" {
  for_each                 = local.service_config
  type                     = "egress"
  from_port                = each.value 
  to_port                  = each.value
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id     
  source_security_group_id = aws_security_group.service_app[each.key].id 
}

resource "aws_security_group_rule" "app_egress_all" {
  for_each          = local.service_config
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"           # 모든 프로토콜 (TCP, UDP, ICMP 등)
  cidr_blocks       = ["0.0.0.0/0"]  # 모든 목적지 허용
  security_group_id = aws_security_group.service_app[each.key].id
}