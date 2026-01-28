output "certificate_arn" {
  description = "ACM 인증서 ARN"
  value       = aws_acm_certificate_validation.cert.certificate_arn
}

output "zone_id" {
  description = "Hosted Zone ID"
  value       = data.aws_route53_zone.this.zone_id
}
