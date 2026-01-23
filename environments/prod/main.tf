locals {
  service_config = {
    "user"    = 80
    "product" = 80
    "trade"   = 80
    "order"   = 80
    "payment" = 80
  }
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "vpc" {
  source             = "../../modules/vpc"
  env                = var.env # variables.tf에서 정의한 변수를 사용
  vpc_cidr           = var.vpc_cidr
  project_name       = var.project_name
  nat_sg_id          = module.security_group.nat_sg_id
  availability_zones = var.availability_zones
}

module "security_group" {
  source       = "../../modules/security_group"
  env          = var.env
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
}

data "aws_secretsmanager_secret" "db_password" {
  name = "${var.project_name}/${var.env}/db-password"
}

data "aws_secretsmanager_secret_version" "db_password_val" {
  secret_id = data.aws_secretsmanager_secret.db_password.id
}

module "waf" {
  source       = "../../modules/waf" # waf 모듈 새로 생성 필요
  env          = var.env
  project_name = var.project_name
  alb_arn      = module.alb.alb_arn # ALB와 연결
}

module "common" {
  source               = "../../modules/common"
  env                  = var.env
  project_name         = var.project_name
  service_config       = local.service_config
  vpc_id               = module.vpc.vpc_id
  cloudtrail_bucket_id = module.s3.cloudtrail_bucket_id
  users = var.users
}

module "s3" {
  source       = "../../modules/s3"
  env          = var.env
  project_name = var.project_name
  kms_key_arn  = module.common.kms_key_arn
}

module "alb" {
  source            = "../../modules/alb"
  env               = var.env
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_group.alb_sg_id # 아까 만든 보안 그룹 ID
  service_config    = local.service_config
}

data "aws_ssm_parameter" "db_password" {
  # common 모듈 배포 후에 값이 수동으로 채워져 있어야 합니다.
  name = "/${var.project_name}/${var.env}/user/DB_PASSWORD"

  # common 모듈이 먼저 생성되어야 하므로 명시적 의존성 추가
  depends_on = [module.common]
}

module "rds" {
  source = "../../modules/rds"

  project_name       = var.project_name
  env                = var.env
  private_subnet_ids = module.vpc.private_db_subnet_ids
  availability_zones = var.availability_zones
  kms_key_arn        = module.common.kms_key_arn

  # 보안 그룹 및 서비스 설정 전달
  service_config = local.service_config
  rds_sg_ids     = module.security_group.rds_sg_ids

  # [핵심] SSM에서 읽어온 실제 비밀번호 값을 전달
  db_password = data.aws_ssm_parameter.db_password.value
}

module "redis" {
  source             = "../../modules/redis" # 모듈 경로 확인해주세요!
  project_name       = var.project_name
  env                = var.env
  private_subnet_ids = module.vpc.private_db_subnet_ids
  redis_sg_id        = module.security_group.redis_sg_id
  kms_key_arn        = module.common.kms_key_arn
}

module "msk" {
  source                = "../../modules/msk"
  project_name          = var.project_name
  env                   = var.env
  private_db_subnet_ids = module.vpc.private_db_subnet_ids
  msk_sg_id             = module.security_group.msk_sg_id # SG 모듈에 msk_sg_id가 있어야 함
  kms_key_arn           = module.common.kms_key_arn       # 혹은 따로 만든 kms arn
}

module "ecs" {
  source = "../../modules/ecs"

  project_name   = var.project_name
  env            = var.env
  app_subnet_ids = module.vpc.private_app_subnet_ids
  aws_region = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
  # 1. MSK 주소 전달 (이게 빠져서 에러가 난 겁니다!)
  msk_bootstrap_brokers = module.msk.bootstrap_brokers
  service_config        = local.service_config
  # 2. ALB 타겟 그룹 전달
  target_group_arns = module.alb.target_group_arns

  # 3. 보안 그룹 전달 (중복 제거 및 이름 확인)
  # 아까 SG 아웃풋에 ecs_sg_id가 없었으니, 공통으로 쓸 app_sg_ids["user"] 등을 넣거나
  # SG 모듈의 아웃풋 이름을 ecs_sg_id로 수정해야 합니다.
  ecs_sg_id = module.security_group.app_sg_ids["user"]

  # 4. IAM 역할 전달
  ecs_task_execution_role_arn = module.common.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.common.ecs_task_role_arn
}