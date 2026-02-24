variable "env" {}

variable "project_name" {}

variable "vpc_id" {}

variable "service_config" {
  description = "Map of service names and their ports"
  type        = map(number)
}

variable "extra_service_config" {
  description = "Map of extra infra service names and their ports (e.g. argocd, grafana)"
  type        = map(number)
  default     = {}
}
