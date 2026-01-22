# 내부 서비스 탐색을 위한 프라이빗 DNS 네임스페이스
resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = "${var.project_name}.local"
  description = "${var.project_name} ${var.env} 마이크로서비스 탐색용"
  vpc         = var.vpc_id # VPC 모듈에서 받아온 ID 연결
}