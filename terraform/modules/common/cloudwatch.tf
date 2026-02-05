resource "aws_cloudwatch_log_group" "services" {
  for_each = var.service_config

  name              = "/ecs/${var.project_name}-${var.env}-${each.key}"
  retention_in_days = var.env == "prod" ? 30 : 7

  tags = {
    Name = "${var.project_name}-${var.env}-${each.key}-log"
  }
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.project_name}-${var.env}-trail-logs"
  retention_in_days = var.env == "prod" ? 30 : 7
}