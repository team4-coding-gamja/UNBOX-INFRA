# modules/vpc/outputs.tf

output "vpc_id" {
  description = "생성된 VPC의 ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "생성된 퍼블릭 서브넷 ID 리스트"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  value = aws_subnet.app[*].id
}

output "private_db_subnet_ids" {
  value = aws_subnet.db[*].id
}