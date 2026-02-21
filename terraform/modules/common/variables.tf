####################### I AM ########################
variable "env" {
  description = "환경 구분"
}

variable "project_name" {
  description = "프로젝트 이름"
}

variable "service_config" {
  description = "서비스별 이름과 포트 매핑 정보"
  type        = map(number)
}

variable "vpc_id" {
  description = "Cloud Map을 생성할 VPC ID"
  type        = string
}

variable "users" {
  description = "IAM Identity Center 사용자 명단"
  type = map(object({
    user_name   = string
    display     = string
    given_name  = string
    family_name = string
  }))
}

variable "kms_key_arn" {

}

####################### Cloud Trail ########################
variable "cloudtrail_bucket_id" {
  type = string
}

####################### ACM #########################
variable "route53_zone_id" {
  type    = string
  default = "this is route default"
}
variable "domain_name" {
  type    = string
  default = "domain_name_default"
}

####################### WAF #######################

variable "aws_region" {
  type    = string
  default = null
}



variable "account_id" {
  type    = string
  default = null
}

variable "private_app_subnet_ids" {
  description = "Lambda가 배포될 Private Subnet 목록"
  type        = list(string)
  default     = []
}

variable "app_sg_ids" {
  description = "Lambda에 할당할 앱 보안 그룹 (RDS 접근용)"
  type        = map(string)
  default     = {}
}
