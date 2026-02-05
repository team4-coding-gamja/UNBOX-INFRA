variable "project_name" { type = string }
variable "env"          { type = string }
variable "private_db_subnet_ids" { 
  type        = list(string)
  description = "VPC에서 고정했던 그 이름 그대로!"
}
variable "msk_sg_id"    { type = string }
variable "kms_key_arn"  { type = string }