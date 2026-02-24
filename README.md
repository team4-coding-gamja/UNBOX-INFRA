# UNBOX-INFRA

UNBOX 인프라(IaC) 관리 저장소입니다.  
AWS 인프라는 Terraform으로 관리하고, Kubernetes 리소스는 GitOps 매니페스트로 관리합니다.

## Repository Structure

```txt
unbox-infra/
├── terraform/
│   ├── environments/
│   │   ├── bootstrap/     # state backend(S3, DynamoDB), ECR/Secrets 초기 리소스
│   │   ├── dev/           # 개발 환경 실행 디렉토리
│   │   └── prod/          # 운영 환경 실행 디렉토리
│   └── modules/
│       ├── alb/
│       ├── common/
│       ├── eks/
│       ├── monitoring/
│       ├── msk/
│       ├── rds/
│       ├── redis/
│       ├── route53/
│       ├── s3/
│       ├── security_group/
│       └── vpc/
├── gitops/
│   ├── apps/              # 서비스별 애플리케이션 매니페스트
│   ├── charts/            # 공통 Helm chart 템플릿
│   └── infra/             # 클러스터 인프라 컴포넌트(ArgoCD, Linkerd, Monitoring 등)
└── argocd/                # ArgoCD 관련 설정
```

## Infra Overview

- Network: VPC + Public/Private/Data 서브넷
- Compute: EKS (dev/prod), 일부 워크로드 Fargate 사용 가능
- Data: RDS, Redis, MSK
- Edge/DNS: ALB, Route53, ACM
- Security/Common: IAM, KMS, S3, SSM, Secrets Manager, CloudWatch, CloudTrail

## Prerequisites

- Terraform `v1.5+`
- AWS CLI 인증 완료
- 환경별 변수 파일 준비 (`terraform/environments/{env}/terraform.tfvars`)

주의:
- `terraform.tfvars` 는 Git에 커밋하지 않습니다.

## Terraform Workflow

### 1) Bootstrap (최초 1회 또는 변경 시)

```bash
cd terraform/environments/bootstrap
terraform init
terraform plan
terraform apply
```

### 2) Environment 배포 (dev/prod)

```bash
cd terraform/environments/dev   # 또는 prod
terraform init
terraform plan
terraform apply
```

## 운영 원칙

- 수동 콘솔 변경 대신 Terraform/GitOps 기준으로 변경 관리
- `plan` 검토 후 `apply`
- state backend(S3) + lock(DynamoDB) 사용
- 모듈 재사용 중심으로 환경(dev/prod) 분리 운영
