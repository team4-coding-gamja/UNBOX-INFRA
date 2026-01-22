# # 1. SSL 인증서 신청
# resource "aws_acm_certificate" "this" {
#   domain_name       = "*.${var.domain_name}" # 메인 도메인과 서브 도메인 모두 포함
#   validation_method = "DNS"

#   subject_alternative_names = [
#     var.domain_name
#   ]

#   lifecycle {
#     create_before_destroy = true
#   }

#   tags = {
#     Name = "${var.project_name}-${var.env}-certificate"
#   }
# }

# # 2. DNS 검증을 위한 Route53 레코드 생성
# # "내가 이 도메인 주인 맞아요"라고 증명하는 과정입니다.
# resource "aws_route53_record" "acm_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }

#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = var.route53_zone_id # Route53 호스팅 영역 ID
# }

# # 3. 인증서 검증 완료 대기 (이게 있어야 테라폼이 발급 완료까지 기다려줍니다)
# resource "aws_acm_certificate_validation" "this" {
#   certificate_arn         = aws_acm_certificate.this.arn
#   validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
# }