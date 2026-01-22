resource "aws_secretsmanager_secret" "service_secrets" {
  for_each = var.env == "prod" ? var.service_config : {}

  name        = "${var.project_name}/${var.env}/${each.key}-secrets"
  description = "${each.key} service secrets for production"
  kms_key_id  = aws_kms_key.this.arn # 우리가 만든 KMS로 암호화

  tags = {
    Name = "${var.project_name}-${var.env}-${each.key}-secrets"
  }
}