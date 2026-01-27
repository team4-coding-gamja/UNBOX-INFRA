variable "project_name" {
  description = "Project name"
  type        = string
}

variable "env" {
  description = "Environment (dev/prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security Group ID for ALB"
  type        = string
}

variable "service_config" {
  description = "Map of service names and their ports"
  type        = map(number)
}

variable "certificate_arn" {
  description = "ACM Certificate ARN for HTTPS (Optional)"
  type        = string
  default     = null
}
