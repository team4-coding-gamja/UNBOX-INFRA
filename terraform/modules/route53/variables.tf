variable "domain_name" {
  description = "도메인 이름 (예: dev.un-box.click)"
  type        = string
}

variable "hosted_zone_name" {
  description = "Hosted Zone 이름 (예: un-box.click). 기본값은 domain_name과 동일"
  type        = string
  default     = null
}

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB의 DNS 이름"
  type        = string
}

variable "alb_zone_id" {
  description = "ALB의 Hosted Zone ID"
  type        = string
}

