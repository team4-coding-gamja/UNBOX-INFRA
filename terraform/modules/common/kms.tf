data "aws_kms_alias" "infra_key" {
  name = "alias/${var.project_name}/dev/main-key"
}