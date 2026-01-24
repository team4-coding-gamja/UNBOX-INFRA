variable "project_name" {}
variable "env" {}
variable "kms_key_arn" {}
variable "private_subnet_ids" { type = list(string) }
variable "availability_zones" { type = list(string) }

variable "db_password" {
  type      = string
  sensitive = true
}

variable "service_config" {
  type = map(number)
}

variable "rds_sg_ids" {
  type = map(string)
}

# 서비스별 DB 비밀번호 (Dev 환경용)
variable "service_db_passwords" {
  type      = map(string)
  sensitive = true
  default   = {}
}