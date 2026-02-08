variable "env" {}

variable "project_name" {}

variable "vpc_id" {}

variable "service_config" {
  description = "Map of service names and their ports"
  type        = map(number)
}
