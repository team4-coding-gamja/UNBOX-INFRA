# modules/vpc/variables.tf

variable "env" {
  description = "환경 구분"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
}

variable "project_name" {
  description = "프로젝트 이름"
}

variable "nat_sg_id" {
  description = "NAT Instance용 보안 그룹 ID (DEV 환경 전용)"
  default     = "" # PROD에서는 필요 없으므로 기본값 비워둠
}

variable "availability_zones" {
  type = list(string)
}

variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}
