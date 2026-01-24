# WAF는 prod 환경에서만 생성
resource "aws_wafv2_web_acl" "main" {
  count       = var.env == "prod" ? 1 : 0
  name        = "${var.project_name}-${var.env}-waf"
  description = "OWASP Top 10 Managed Rule Set"
  scope       = "REGIONAL" # ALB 연결용

  default_action {
    allow {}
  }

  # 딱 이거 하나! Core Rule Set (CRS)
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "unbox-waf-metric"
    sampled_requests_enabled   = true
  }
}

# [필수] ALB와 WAF를 연결해주는 코드
resource "aws_wafv2_web_acl_association" "main" {
  count        = var.env == "prod" ? 1 : 0
  resource_arn = var.alb_arn # ALB의 ARN을 넣어줘야 합니다.
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
}

# WAF 로깅은 추후 Kinesis Firehose 설정 후 활성화
# resource "aws_wafv2_web_acl_logging_configuration" "main" {
#   count        = var.env == "prod" ? 1 : 0
#   resource_arn = aws_wafv2_web_acl.main[0].arn
#
#   log_destination_configs = [
#     aws_kinesis_firehose_delivery_stream.waf_logs.arn
#   ]
# }