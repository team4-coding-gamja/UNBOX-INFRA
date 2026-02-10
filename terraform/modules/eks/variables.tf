# modules/eks/variables.tf

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "env" {
  description = "환경 (dev/prod)"
  type        = string
}

variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "cluster_version" {
  description = "EKS Kubernetes 버전"
  type        = string
  default     = "1.35"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "EKS 클러스터 및 노드 그룹이 배치될 서브넷 ID 리스트"
  type        = list(string)
}

variable "node_desired_size" {
  description = "워커 노드 희망 개수"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "워커 노드 최소 개수"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "워커 노드 최대 개수"
  type        = number
  default     = 5
}

variable "instance_types" {
  description = "워커 노드 인스턴스 타입"
  type        = list(string)
  default     = ["t3.large"]
}

variable "enable_fargate" {
  description = "Fargate 프로필 활성화 여부 (Prod 환경 전용)"
  type        = bool
  default     = false
}

variable "fargate_namespace" {
  description = "Fargate를 사용할 Kubernetes 네임스페이스"
  type        = string
  default     = "serverless" # 필요 시 default 등으로 변경 가능
}

variable "cluster_role_arn" {
  description = "EKS Cluster IAM Role ARN"
  type        = string
}

variable "node_role_arn" {
  description = "EKS Node Group IAM Role ARN"
  type        = string
}


variable "fargate_profile_role_arn" {
  description = "EKS Fargate Profile IAM Role ARN"
  type        = string
  default     = null
}

variable "node_security_group_id" {
  description = "Security Group ID to attach to Worker Nodes"
  type        = string
  default     = ""
}

variable "kms_key_arn" {
  description = "EKS Node EBS Volume KMS Key ARN"
  type        = string
}

variable "aws_auth_users" {
  description = "Additional IAM users to add to the aws-auth configmap."
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "aws_auth_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "argocd_admin_password" {
  description = "ArgoCD admin 초기 비밀번호"
  type        = string
  default     = "unbox1234!"
  sensitive   = true
}
