variable "project_name" {}
variable "env" {}
variable "kms_key_arn" {}
variable "private_subnet_ids" { type = list(string) }
variable "availability_zones" { type = list(string) }

variable "service_db_passwords" {
  type      = map(string)
  sensitive = true
  description = "서비스별 비밀번호 맵"
}

variable "service_config" {
  type = map(number)
}

variable "rds_sg_ids" {
  type = map(string)
}
