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