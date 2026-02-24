# envs/dev/variables.tf
variable "env" {
  default = "dev"
}

variable "project_name" {
  default = "unbox"
}

variable "vpc_cidr" {
  default = "10.1.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "users" {
  type = map(object({
    user_name   = string
    display     = string
    given_name  = string
    family_name = string
  }))
}

variable "kms_key_arn" {
  description = "KMS ARN from bootstrap"
  type        = string
}

variable "toss_secret_key" {
  description = "Toss Payments Secret Key"
  type        = string
  sensitive   = true
}

variable "toss_security_key" {
  description = "Toss Payments Security Key"
  type        = string
  sensitive   = true
}



variable "argocd_admin_password" {
  description = "ArgoCD admin 초기 비밀번호"
  type        = string
  default     = "RKgus12!"
  sensitive   = true
}

variable "enable_alb" {
  description = "Enable ALB related resources and lookups"
  type        = bool
  default     = false
}

