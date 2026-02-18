# envs/dev/variables.tf
variable "env" {
  default = "prod"
}

variable "project_name" {
  default = "unbox"
}

variable "vpc_cidr" {
  default = "10.00.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-northeast-2a", "ap-northeast-2c"] # 서울 리전 기준
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

variable "aws_region" {
  type = string
}

variable "account_id" {
  type = string
}
variable "enable_karpenter" {
  description = "Enable Karpenter for autoscaling"
  type        = bool
  default     = true
}

variable "toss_secret_key" {
  type = string
}

variable "toss_security_key" {
  type = string
}

variable "enable_alb" {
  description = "Enable ALB and related resources"
  type        = bool
  default     = true
}
