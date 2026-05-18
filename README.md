# UNBOX-INFRA

UNBOX 서비스의 인프라를 코드로 관리하는 저장소입니다.

- AWS 인프라 계층: Terraform
- Kubernetes 앱/인프라 배포 계층: ArgoCD + GitOps
- 서비스 배포 전략: Argo Rollouts (Canary / BlueGreen)
- 서비스 메시: Linkerd
- 관측: Prometheus, Grafana, Loki, Tempo, Fluent Bit

<img width="2523" height="1843" alt="prod architecture" src="https://github.com/user-attachments/assets/e165a0ec-45df-4127-bebf-208cd9fa59a2" />

## 1. 아키텍처 개요

이 프로젝트는 크게 4개 레이어로 동작합니다.

1. Cloud Foundation (Terraform)
- VPC, Subnet, NAT, Security Group, IAM, KMS, S3, Route53, ACM, RDS, Redis, MSK, EKS 등

2. Cluster Infra (GitOps)
- cert-manager, external-secrets, linkerd, trust-manager, monitoring stack, kafka, karpenter(Prod) 등

3. App Runtime (GitOps)
- user/product/order/trade/payment 서비스
- 공통 Helm 템플릿(`gitops/charts`) 기반으로 환경별 values 적용

4. Delivery / Operations
- ArgoCD 자동 동기화(Self-heal / Prune)
- Argo Rollouts 기반 무중단/점진 배포
- Prometheus/Grafana/Loki/Tempo 기반 모니터링/로그/트레이싱

## 2. 저장소 구조

```txt
unbox-infra/
├── terraform/
│   ├── environments/
│   │   ├── bootstrap/     # 초기 1회 리소스 (state backend, ECR, secrets seed 등)
│   │   ├── dev/           # dev 환경 루트
│   │   └── prod/          # prod 환경 루트
│   └── modules/
│       ├── vpc/
│       ├── security_group/
│       ├── eks/
│       ├── common/
│       ├── s3/
│       ├── rds/
│       ├── redis/
│       ├── msk/
│       ├── route53/
│       ├── alb/
│       └── monitoring/
├── gitops/
│   ├── apps/              # 서비스별 app manifest + values
│   ├── charts/            # 공통 app chart 템플릿
│   └── infra/             # 클러스터 인프라 애드온 manifest
└── argocd/                # bundle(app-of-apps) 엔트리
```

## 3. Terraform 상세 구조

### 3.1 environments

- `terraform/environments/bootstrap`
  - 목적: 초기 전역성 리소스 구성
  - 예: Terraform state backend(S3), state lock(DynamoDB), ECR, 초기 secret 자원

- `terraform/environments/dev`
  - dev 환경 전체 인프라를 모듈 조합으로 구성
  - 주요 파일:
    - `main.tf`: 모듈 호출, 리소스 오케스트레이션
    - `variables.tf`: 환경 변수 입력 정의
    - `providers.tf`: provider 설정
    - `backend.tf`: 원격 state 연결
    - `ssm.tf`: SSM 파라미터 관련 리소스
    - `security_rules.tf`: SG rule 보강

- `terraform/environments/prod`
  - prod 환경 전체 인프라
  - dev와 동일 구조이나 가용성/보안/스케일 정책이 다르게 적용됨

### 3.2 modules 역할

- `vpc`
  - VPC, 서브넷 계층(Public/Private App/Private DB), 라우팅, NAT/IGW 기반 네트워크 토대

- `security_group`
  - EKS/ALB/RDS/Redis/NAT/서비스별 SG 및 규칙 관리

- `eks`
  - EKS 클러스터/노드그룹/Fargate(환경별), OIDC(IRSA), LB Controller, cert-manager, ESO, ArgoCD 등 클러스터 핵심 컴포넌트 설치

- `common`
  - IAM, KMS, CloudTrail, CloudWatch, SSM, Secrets 관련 공통 리소스

- `s3`
  - 로그/공용 목적 버킷 및 정책

- `rds`
  - 서비스별 DB 엔드포인트/보안연계

- `redis`
  - ElastiCache Redis 구성 및 암호화/접근 정책

- `msk`
  - Kafka(MSK) 관련 리소스

- `route53`
  - DNS record/zone/도메인 연결

- `alb`
  - ALB 관련 리소스(현재 사용 전략에 따라 일부 경로는 K8s Ingress 중심)

- `monitoring`
  - 모니터링 인프라와 연동되는 클라우드 리소스(필요 시)

## 4. GitOps 상세 구조

### 4.1 apps (`gitops/apps`)

서비스별 디렉토리:
- `user`, `product`, `order`, `trade`, `payment`

각 서비스는 보통 다음 파일을 가짐:
- `application-dev.yaml`, `application-prod.yaml`
- `values.yaml`(기본)
- `values-dev.yaml`, `values-prod.yaml`(환경 오버라이드)

앱 배포는 공통 차트(`gitops/charts`)를 사용하며,
서비스별 values로 이미지/리소스/env/롤아웃 전략을 주입합니다.

### 4.2 charts (`gitops/charts`)

공통 템플릿:
- `rollout.yaml` (Argo Rollouts)
- `service.yaml`
- `ingress.yaml`
- `servicemonitor.yaml`
- `trafficsplit.yaml`
- `analysistemplate.yaml`

핵심 포인트:
- `linkerd.enabled`가 true이면 sidecar injection annotation 포함
- 서비스별 health check path/rollout 설정을 values로 분리
- canary 분석 쿼리/프로메테우스 주소를 템플릿화

### 4.3 infra (`gitops/infra`)

클러스터 인프라 앱:
- `cert-manager`
- `external-secrets`
- `linkerd` / `linkerd-smi` / `trust-bundle`
- `trust-manager`(Prod)
- `monitoring`(kube-prometheus-stack, loki, tempo, fluent-bit)
- `kafka`
- `karpenter`(Prod)
- `metrics-server`(Prod)
- `ingress-gateway`(환경에 따라 운영 전략 결정 필요)

## 5. ArgoCD 번들 전략

`argocd/` 디렉토리는 App-of-Apps 번들 엔트리입니다.

- `infra-bundle-dev.yaml`: dev 인프라 앱 묶음
- `infra-bundle-prod.yaml`: prod 인프라 앱 묶음
- `dev-bundle.yaml`: dev 서비스 앱 묶음
- `prod-bundle.yaml`: prod 서비스 앱 묶음

권장 원칙:
- 공용 `infra-bundle.yaml`보다 환경별 bundle 사용을 권장
- 순서: infra bundle 먼저, app bundle 나중

## 6. Secret / Config 흐름

1. Terraform이 SSM/Secrets Manager 경로를 준비
2. External Secrets가 AWS에서 값을 pull
3. Kubernetes Secret(`db-secret` 등) 생성/갱신
4. 앱 Deployment/Rollout이 SecretKeyRef로 주입

- 환경별 경로(`/unbox/dev/...`, `/unbox/prod/...`)를 혼용하면 주입 실패 원인

## 7. 트래픽/네트워킹 경로

기본 흐름:
- Client -> Route53 -> ALB -> Ingress -> Service -> Pod

서비스 메시 흐름(Linkerd 사용 시):
- Pod <-> Pod 트래픽에 sidecar proxy 개입
- mTLS/메트릭/트래픽 제어(특히 Rollout canary traffic split) 지원

## 8. 관측(Observability) 구조

- Metrics: Prometheus (kube-prometheus-stack)
- Dashboard: Grafana
- Logs: Fluent Bit -> Loki
- Tracing: Tempo

앱 레벨:
- ServiceMonitor 생성
- rollout 분석(성공률/에러율/응답시간) 쿼리 기반 자동화

서비스 메시 레벨:
- Linkerd 메트릭을 Prometheus로 수집하면 Grafana에서 통신 지표 시각화 가능

## 9. 배포 절차(권장 순서)

### Step 0. Bootstrap (최초 1회/변경 시)

```bash
cd terraform/environments/bootstrap
terraform init
terraform plan
terraform apply
```

### Step 1. 인프라 배포 (env별)

```bash
cd terraform/environments/dev   # 또는 prod
terraform init
terraform plan
terraform apply
```

### Step 2. ArgoCD 인프라 앱 등록

```bash
kubectl apply -f argocd/infra-bundle-dev.yaml    # dev
kubectl apply -f argocd/infra-bundle-prod.yaml   # prod
```

### Step 3. ArgoCD 서비스 앱 등록

```bash
kubectl apply -f argocd/dev-bundle.yaml           # dev
kubectl apply -f argocd/prod-bundle.yaml          # prod
```

## 10. 운영 기준 / 컨벤션

- Terraform:
  - `plan` 검토 없는 `apply` 금지
  - state는 S3 + DynamoDB lock 사용
  - 환경 디렉토리는 코드 중심(`*.tf`)으로 유지

- GitOps:
  - 배포는 ArgoCD를 단일 진입점으로 사용
  - app/infra bundle을 환경별로 분리
  - secret plain text 커밋 금지

- 네이밍/환경:
  - 리소스 이름은 `project-env-role` 규칙 유지
  - dev/prod 값을 chart values에서 명확히 분리

---
