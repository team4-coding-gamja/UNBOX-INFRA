# 1. 사용자가 접속할 도메인 주소 (이걸로 접속합니다)
output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.this.dns_name
}

# 2. ALB ARN
output "alb_arn" {
  description = "The ARN of the load balancer"
  value       = aws_lb.this.arn
}

# 3. 리스너 ARN (나중에 HTTPS 인증서 연결 등에 필요)
output "http_listener_arn" {
  description = "The ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

# 4. 타겟 그룹 ARN 맵 (중요: 나중에 ECS 서비스 만들 때 이 ARN들을 하나씩 꽂아줘야 함)
output "target_group_arns" {
  description = "A map of target group ARNs"
  value       = { for key, tg in aws_lb_target_group.services : key => tg.arn }
}

output "alb_zone_id" {
  description = "ALB의 Hosted Zone ID"
  value       = aws_lb.this.zone_id
}
