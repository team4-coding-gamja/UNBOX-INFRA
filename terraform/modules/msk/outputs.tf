output "bootstrap_brokers" {
  description = "Kafka 접속 주소 (IAM 인증용)"
  # Serverless는 'bootstrap_brokers_sasl_iam' 속성을 사용해야 합니다!
  value = var.env == "prod" ? aws_msk_cluster.provisioned[0].bootstrap_brokers_tls : aws_msk_serverless_cluster.serverless[0].bootstrap_brokers_sasl_iam
}

output "msk_cluster_arn" {
  description = "MSK 클러스터 ARN"
  value       = var.env == "prod" ? aws_msk_cluster.provisioned[0].arn : aws_msk_serverless_cluster.serverless[0].arn
}