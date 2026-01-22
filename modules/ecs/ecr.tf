resource "aws_ecr_repository" "services" {
  for_each = var.service_config

  name                 = "${var.project_name}-${var.env}-${each.key}-repo"
  image_tag_mutability = var.env == "prod" ? "IMMUTABLE" : "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-${var.env}-${each.key}-repo"
  }
}