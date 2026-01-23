# 1. ECS 클러스터 정보
output "cluster_name" {
  description = "ECS 클러스터 이름"
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ECS 클러스터 ARN"
  value       = aws_ecs_cluster.this.arn
}

# 2. ECR 저장소 URL (서비스별로 매핑)
# 결과 예시: { order = "xxx.dkr.ecr.ap-northeast-2.amazonaws.com/unbox-dev-order", ... }
output "ecr_repository_urls" {
  description = "각 서비스별 ECR 저장소 URL 주소"
  value = {
    for k, v in data.aws_ecr_repository.service_ecr : k => v.repository_url
  }
}

# 3. ECS 서비스 ARN
output "service_arns" {
  description = "생성된 ECS 서비스들의 ARN 목록"
  value = {
    for k, v in aws_ecs_service.services : k => v.id
  }
}

# 4. ECS 태스크 정의 패밀리
output "task_definition_families" {
  description = "각 서비스별 태스크 정의 패밀리 이름"
  value = {
    for k, v in aws_ecs_task_definition.services : k => v.family
  }
}