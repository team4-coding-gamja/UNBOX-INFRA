# modules/eks/outputs.tf

output "cluster_endpoint" {
  description = "EKS 클러스터 엔드포인트"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "EKS 클러스터 보안 그룹 ID"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_arn" {
  value = var.cluster_role_arn
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_name" {
  value = aws_eks_cluster.main.name
}
