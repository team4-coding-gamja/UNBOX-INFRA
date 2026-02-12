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
  name = "alias/${var.project_name}/${var.env}/main-key"
}
#ECR경로 가져오기
data "aws_ecr_repository" "service_ecr" {
  for_each = local.service_config
  name     = "${var.project_name}-${var.env}-${each.key}-repo"
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
  source               = "../../modules/common"
  env                  = var.env
  project_name         = var.project_name
  service_config       = local.service_config
  vpc_id               = module.vpc.vpc_id
  cloudtrail_bucket_id = module.s3.cloudtrail_bucket_id
  users                = var.users
  kms_key_arn          = data.aws_kms_alias.infra_key.target_key_arn
  # alb_arn                = module.alb.alb_arn
  private_app_subnet_ids = module.vpc.private_app_subnet_ids # Lambda 배포용
  app_sg_ids             = module.security_group.app_sg_ids  # Lambda SG용
}

module "s3" {
  source       = "../../modules/s3"
  env          = var.env
  project_name = var.project_name
  kms_key_arn  = module.common.kms_key_arn
}

# module "alb" {
#   source            = "../../modules/alb"
#   env               = var.env
#   project_name      = var.project_name
#   vpc_id            = module.vpc.vpc_id
#   public_subnet_ids = module.vpc.public_subnet_ids
#   alb_sg_id         = module.security_group.alb_sg_id # 아까 만든 보안 그룹 ID
#   service_config    = local.service_config
#   certificate_arn   = module.route53.certificate_arn
#   enable_https      = true
#   logs_bucket_id    = module.s3.logs_bucket_id
# }

# Ingress가 생성한 ALB 찾기
data "aws_lb" "ingress" {
  tags = {
    "ingress.k8s.aws/stack" = "${var.project_name}-${var.env}"
  }
}

data "aws_ssm_parameter" "db_password" {
  # common 모듈 배포 후에 값이 수동으로 채워져 있어야 합니다.
  name = "/${var.project_name}/${var.env}/common/DB_PASSWORD"

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
  service_db_passwords = { common = data.aws_ssm_parameter.db_password.value }
}

module "redis" {
  source                     = "../../modules/redis" # 모듈 경로 확인해주세요!
  project_name               = var.project_name
  env                        = var.env
  private_subnet_ids         = module.vpc.private_db_subnet_ids
  redis_sg_id                = module.security_group.redis_sg_id
  kms_key_arn                = module.common.kms_key_arn
  transit_encryption_enabled = var.env == "prod" ? true : false
  auth_token                 = module.common.redis_password_raw
}





module "route53" {
  source           = "../../modules/route53"
  domain_name      = "dev.un-box.click"
  hosted_zone_name = "un-box.click"
  project_name     = var.project_name
  alb_dns_name     = data.aws_lb.ingress.dns_name
  alb_zone_id      = data.aws_lb.ingress.zone_id
}

# Grafana DNS 레코드 추가 (Ingress 연결)
resource "aws_route53_record" "grafana" {
  zone_id = module.route53.zone_id
  name    = "grafana.dev.un-box.click"
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress.dns_name
    zone_id                = data.aws_lb.ingress.zone_id
    evaluate_target_health = true
  }
}

module "eks" {
  source = "../../modules/eks"

  project_name = var.project_name
  env          = var.env
  cluster_name = "unbox-cluster" # VPC와 이름 일치

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_app_subnet_ids # App 서브넷에 노드 배치

  # Dev 환경: 3 Nodes (Monitoring Stack 추가로 인한 증설)
  node_desired_size = 3
  node_min_size     = 3
  node_max_size     = 3
  instance_types    = ["t3.large"]
  enable_fargate    = false

  cluster_role_arn         = module.common.eks_cluster_role_arn
  node_role_arn            = module.common.eks_node_role_arn
  fargate_profile_role_arn = module.common.eks_fargate_role_arn
  kms_key_arn              = module.common.kms_key_arn
  node_security_group_id   = module.security_group.eks_node_sg_id

  # ArgoCD 설정
  argocd_admin_password = var.argocd_admin_password

  # AWS Auth (Manage Access)
  aws_auth_users = [
    for key, user in var.users : {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${user.user_name}"
      username = user.user_name
      groups   = ["system:masters"] # Full Admin Access
    }
  ]
}

# [Fix] EKS Cluster -> RDS Security Group Rule (Avoid Cyclic Dependency)
resource "aws_security_group_rule" "rds_ingress_from_eks_cluster" {
  for_each                 = local.service_config
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = module.security_group.rds_sg_ids[each.key]
  source_security_group_id = module.security_group.eks_node_sg_id
  description              = "Allow EKS Worker Nodes to access RDS"
}
