# 1. DB 서브넷 그룹
resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-${var.env}-rds-sng"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.project_name}-${var.env}-rds-sng" }
}

# 2. RDS 인스턴스 (PostgreSQL)
resource "aws_db_instance" "postgresql" {
  # [로직] Prod는 5개 서비스 각각 / Dev는 'common' 하나만
  for_each = var.env == "prod" ? toset(keys(var.service_config)) : (var.env == "dev" ? toset(["common"]) : toset([]))

  identifier     = "${var.project_name}-${var.env}-${each.key}-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"
  allocated_storage = 20

  db_name  = var.env == "prod" ? "${each.key}_db" : "dev_db"
  username = "unbox_admin"
  password = (
    var.env == "prod" 
    ? var.service_db_passwords[each.key] 
    : var.service_db_passwords["user"]
  )

  db_subnet_group_name = aws_db_subnet_group.this.name

  # Prod: 각 서비스(user, product 등)에 맞는 SG ID 연결
  # Dev: service_rds["user"] SG를 공용으로 사용 (또는 요구사항에 맞는 SG 연결)
  vpc_security_group_ids = var.env == "prod" ? [var.rds_sg_ids[each.key]] : values(var.rds_sg_ids)

  multi_az                = var.env == "prod" ? true : false
  backup_retention_period = var.env == "prod" ? 7 : 0
  skip_final_snapshot     = var.env == "prod" ? false : true
  
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn
  lifecycle { 
    ignore_changes = [password]
  }
  tags = { Name = "${var.project_name}-${var.env}-${each.key}-db" }
}