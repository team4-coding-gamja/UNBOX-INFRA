locals {
  service_config = {
    "user"    = 8081
    "product" = 8082
    "trade"   = 8083
    "order"   = 8084
    "payment" = 8085
  }
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_kms_alias" "infra_key" {
  name = "alias/${var.project_name}/dev/main-key" # Using shared dev KMS key
}

module "vpc" {
  source             = "../../modules/vpc"
  env                = var.env # variables.tf에서 정의한 변수를 사용
  vpc_cidr           = var.vpc_cidr
  project_name       = var.project_name
  nat_sg_id          = module.security_group.nat_sg_id
  availability_zones = var.availability_zones
  cluster_name       = "unbox-cluster"
}

module "security_group" {
  source         = "../../modules/security_group"
  env            = var.env
  project_name   = var.project_name
  vpc_id         = module.vpc.vpc_id
  service_config = local.service_config
}

module "common" {
  source                 = "../../modules/common"
  env                    = var.env
  project_name           = var.project_name
  service_config         = local.service_config
  vpc_id                 = module.vpc.vpc_id
  cloudtrail_bucket_id   = module.s3.cloudtrail_bucket_id
  users                  = var.users
  kms_key_arn            = data.aws_kms_alias.infra_key.target_key_arn
  alb_arn                = module.alb.alb_arn
  private_app_subnet_ids = module.vpc.private_app_subnet_ids
  app_sg_ids             = module.security_group.app_sg_ids
  aws_region             = var.aws_region
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
  certificate_arn   = module.route53.certificate_arn
  enable_https      = true
  logs_bucket_id    = module.s3.logs_bucket_id
}

data "aws_ssm_parameter" "db_password" {
  # common 모듈 배포 후에 값이 수동으로 채워져 있어야 합니다.
  for_each = var.env == "dev" ? toset(keys(local.service_config)) : toset([])

  # [수정 3] 특정 서비스(user)가 아닌 각 서비스별 경로를 동적으로 가져옵니다.
  name = "/${var.project_name}/${var.env}/${each.key}/DB_PASSWORD"

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
  service_db_passwords = var.env == "prod" ? module.common.service_db_passwords : data.aws_ssm_parameter.db_password["user"].value
}

module "redis" {
  source                     = "../../modules/redis" # 모듈 경로 확인해주세요!
  project_name               = var.project_name
  env                        = var.env
  private_subnet_ids         = module.vpc.private_db_subnet_ids
  redis_sg_id                = module.security_group.redis_sg_id
  kms_key_arn                = module.common.kms_key_arn
  auth_token                 = var.env == "prod" ? module.common.redis_password_raw : null
  transit_encryption_enabled = var.env == "prod" ? true : false
}





module "route53" {
  source       = "../../modules/route53"
  domain_name  = "un-box.click"
  project_name = var.project_name
  alb_dns_name = module.alb.alb_dns_name
  alb_zone_id  = module.alb.alb_zone_id
}

module "eks" {
  source = "../../modules/eks"

  project_name = var.project_name
  env          = var.env
  cluster_name = "unbox-cluster"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_app_subnet_ids

  # Prod 환경: 4 Nodes + Fargate
  node_desired_size = 4
  node_min_size     = 4
  node_max_size     = 10
  instance_types    = ["t3.large"]

  enable_fargate    = true
  fargate_namespace = "serverless" # Fargate로 실행할 파드 네임스페이스

  cluster_role_arn         = module.common.eks_cluster_role_arn
  node_role_arn            = module.common.eks_node_role_arn
  fargate_profile_role_arn = module.common.eks_fargate_role_arn
  kms_key_arn              = module.common.kms_key_arn

  enable_karpenter = var.enable_karpenter
}

# [Fix] EKS Cluster -> RDS Security Group Rule (Avoid Cyclic Dependency)
resource "aws_security_group_rule" "rds_ingress_from_eks_cluster" {
  for_each                 = local.service_config
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = module.security_group.rds_sg_ids[each.key]
  source_security_group_id = module.eks.cluster_security_group_id
  description              = "Allow EKS Cluster Nodes to access RDS"
}

# ========================================
# ACM Certificate for Ingress Gateway
# ========================================

data "aws_route53_zone" "main" {
  count        = var.enable_alb ? 1 : 0
  name         = "un-box.click"
  private_zone = false
}

resource "aws_acm_certificate" "prod" {
  count             = var.enable_alb ? 1 : 0
  domain_name       = "un-box.click"
  validation_method = "DNS"

  subject_alternative_names = ["*.un-box.click"]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-prod-acm-cert"
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_alb ? {
    for dvo in aws_acm_certificate.prod[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main[0].zone_id
}

resource "aws_acm_certificate_validation" "prod" {
  count                   = var.enable_alb ? 1 : 0
  certificate_arn         = aws_acm_certificate.prod[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ACM ARN을 SSM Parameter Store에 저장
resource "aws_ssm_parameter" "acm_certificate_arn" {
  count     = var.enable_alb ? 1 : 0
  name      = "/${var.project_name}/${var.env}/acm/certificate_arn"
  type      = "String"
  value     = aws_acm_certificate.prod[0].arn
  overwrite = true

  tags = {
    Name = "${var.project_name}-${var.env}-acm-arn"
  }

  depends_on = [aws_acm_certificate_validation.prod]
}
