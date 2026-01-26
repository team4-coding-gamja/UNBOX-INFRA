# UNBOX-INFRA

UNBOX 프로젝트의 안정적인 운영을 위한 인프라 관리 저장소 (IaC)  
Terraform 기반 AWS 인프라 구성 레포지토리

---

## Repository Structure

```txt
unbox-infrastructure/
├── environments/        # 환경별 실행 디렉토리 (Live 환경)
│   ├── dev/             # 개발 환경
│   └── prod/            # 운영 환경
│
├── modules/             # 공통 리소스 정의 모듈 (Reusable Components)
│   ├── vpc/             # 네트워크 (VPC, Subnet, IGW, NAT)
│   ├── ecs/             # ECS Cluster, Service, Task Definition
│   ├── rds/             # RDS (Database)
│   ├── msk/             # Kafka (MSK)
│   ├── alb/             # Load Balancer
│   └── common/          # 공통 리소스 (IAM, KMS, S3, CloudWatch, CloudMap 등)
│
├── bootstrap/           # 인프라 초기 세팅
│   ├── s3-backend.tf    # Terraform State 저장용 S3
│   └── dynamodb.tf      # Terraform Lock 관리용 DynamoDB
```

---

## Network Architecture (Production)

운영 환경은 고가용성(High Availability)을 고려한 3-Tier Architecture 구조로 설계되었습니다.

### VPC
- CIDR: 10.0.0.0/16

### Subnet Tier Structure
- Public Subnet: ALB, NAT Gateway  
- Private Subnet: Application Servers (ECS)  
- Data Subnet: Databases (RDS, MSK, Redis)

### Availability Zones
- ap-northeast-2a  
- ap-northeast-2c  

Multi-AZ 기반 고가용성 구조

---

## Quick Start

### Prerequisites
- Terraform v1.5+
- AWS CLI 인증 설정
- terraform.tfvars 파일 작성 (개인정보 및 시크릿 포함)

> terraform.tfvars 파일은 Git에 절대 커밋되지 않으며 .gitignore 처리되어 있습니다.

---

### Deployment

```bash
# 1. 원하는 환경으로 이동
cd environments/prod

# 2. 테라폼 초기화
terraform init

# 3. 변경 사항 검토 (필수)
terraform plan

# 4. 인프라 배포
terraform apply
```

---

## Security Policy

### Secret Management

IMPORTANT:
- terraform.tfvars 파일 Git 커밋 금지
- 민감정보(이메일, 비밀번호, 토큰 등)는
  terraform.tfvars.example 참고하여 로컬에서만 작성

---

### State Lock

WARNING:
- Terraform State 관리:
  - S3 Backend
  - DynamoDB Lock
- 동시 apply 방지 구조
- terraform apply 도중 강제 종료 금지

---

## Workflows

### Branch Strategy
- 모든 변경은 Feature Branch에서 시작

### Review Process
- PR 생성 시 terraform plan 결과 포함
- 팀원 리뷰 필수
- 승인 후 main 브랜치 merge

### CI/CD
- main 브랜치 merge 시 GitHub Actions 실행
- Terraform 자동 배포
- 실제 AWS 인프라 반영

---

## Design Philosophy

- Infrastructure as Code (IaC)
- Immutable Infrastructure
- Environment Isolation (dev/prod)
- Least Privilege Security
- High Availability
- Modular Architecture
- Production-Grade Terraform Structure

---

## Operation Principles

- 수동 콘솔 작업 금지
- 모든 변경은 Terraform으로만 관리
- 단일 책임 모듈 구조
- 재현 가능한 인프라 구성
- 자동화 기반 운영
