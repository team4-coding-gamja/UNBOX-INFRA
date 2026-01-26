# ECS 모듈 업데이트 내역

## 2026-01-26: 서비스별 보안 그룹 적용

### 📋 변경 부분

ECS 서비스가 각자의 보안 그룹을 사용하도록 수정하여 Redis/RDS 접근 권한 문제를 해결했습니다.

**문제:**
- 모든 서비스가 user 서비스의 보안 그룹만 사용
- Redis 연결 실패: `Unable to connect to Redis server`

**해결:**
- 각 서비스가 자신의 보안 그룹 사용
- 보안 그룹별로 Redis/RDS 인바운드/아웃바운드 규칙 적용

---

## 🔧 수정된 파일

### 1. `modules/ecs/variables.tf` (수정)

**변경 전:**
```hcl
variable "ecs_sg_id" {
  description = "ECS Task에 적용할 보안 그룹 ID"
  type        = string
}
```

**변경 후:**
```hcl
variable "ecs_sg_ids" {
  description = "각 서비스별 ECS Task에 적용할 보안 그룹 ID 맵"
  type        = map(string)
}
```

### 2. `modules/ecs/main.tf` (수정)

**변경 전:**
```hcl
network_configuration {
  subnets          = var.env == "dev" ? [var.app_subnet_ids[0]] : var.app_subnet_ids
  security_groups  = [var.ecs_sg_id]
  assign_public_ip = false
}
```

**변경 후:**
```hcl
network_configuration {
  subnets          = var.env == "dev" ? [var.app_subnet_ids[0]] : var.app_subnet_ids
  security_groups  = [var.ecs_sg_ids[each.key]]
  assign_public_ip = false
}
```

---

## 📝 사용 예시

### terraform/environments/dev/main.tf

```hcl
module "ecs" {
  source = "git::https://github.com/team4-coding-gamja/UNBOX-INFRA.git//modules/ecs?ref=main"
  
  # 변경 전
  ecs_sg_id = module.security_group.app_sg_ids["user"]
  
  # 변경 후
  ecs_sg_ids = module.security_group.app_sg_ids
  # {
  #   user    = "sg-xxx1"
  #   product = "sg-xxx2"
  #   trade   = "sg-xxx3"
  #   order   = "sg-xxx4"
  #   payment = "sg-xxx5"
  # }
}
```

---

## ⚠️ Breaking Changes

### 변수 타입 변경

`ecs_sg_id` (string) → `ecs_sg_ids` (map)

기존 코드를 사용 중이라면 반드시 수정해야 합니다.

---

## 👥 기여자

- @gahyun - 서비스별 보안 그룹 적용

---

## 2026-01-26: DB 환경 변수 이름 통일 및 JDBC URL 수정

### 📋 변경 부분

백엔드 application.yml과 인프라 코드 간 환경 변수 이름을 통일하고, JDBC URL 형식을 수정했습니다.

**변경 사항:**
1. 환경 변수 이름 통일: `SPRING_DATASOURCE_*` → `DB_*`
2. JDBC URL 프리픽스 추가: `jdbc:postgresql://` 포함

---

## 🔧 수정된 파일

### 1. `modules/ecs/main.tf` (수정)

#### 환경 변수 이름 변경

**변경 전:**
```hcl
{ 
  name  = "SPRING_DATASOURCE_URL"
  value = "jdbc:postgresql://${var.env == "dev" ? var.rds_endpoints["common"] : var.rds_endpoints[each.key]}/unbox_${each.key}"
},
{ name = "SPRING_DATASOURCE_USERNAME", value = "unbox_${each.key}" },
```

**변경 후:**
```hcl
{ 
  name  = "DB_URL"
  value = "jdbc:postgresql://${var.env == "dev" ? var.rds_endpoints["common"] : var.rds_endpoints[each.key]}/unbox_${each.key}"
},
{ name = "DB_USERNAME", value = "unbox_${each.key}" },
```

#### Secrets 이름 변경

**변경 전:**
```hcl
{
  name      = "SPRING_DATASOURCE_PASSWORD"
  valueFrom = "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/${var.project_name}/${var.env}/${each.key}/DB_PASSWORD"
}
```

**변경 후:**
```hcl
{
  name      = "DB_PASSWORD"
  valueFrom = "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/${var.project_name}/${var.env}/${each.key}/DB_PASSWORD"
}
```

---

## 📝 백엔드 application.yml 형식

모든 서비스가 동일한 환경 변수 이름을 사용합니다:

```yaml
spring:
  datasource:
    driver-class-name: ${DB_DRIVER_CLASS_NAME}
    url: ${DB_URL}
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
```

---

## 🎯 제공되는 환경 변수

### 데이터베이스 관련
- `DB_URL`: JDBC URL (예: `jdbc:postgresql://unbox-dev-common-db.xxx.rds.amazonaws.com:5432/unbox_user`)
- `DB_USERNAME`: 데이터베이스 사용자 (예: `unbox_user`)
- `DB_PASSWORD`: 데이터베이스 비밀번호 (SSM에서 로드)
- `DB_DRIVER_CLASS_NAME`: JDBC 드라이버 클래스 (`org.postgresql.Driver`)

### Redis 관련
- `SPRING_DATA_REDIS_HOST`: Redis 호스트
- `SPRING_DATA_REDIS_PORT`: Redis 포트 (6379)

### 기타
- `SPRING_PROFILES_ACTIVE`: 환경 (dev/prod)
- `SERVER_PORT`: 서비스 포트
- `KAFKA_BOOTSTRAP_SERVERS`: Kafka 브로커 주소
- `SPRING_JWT_SECRET`: JWT 시크릿 (SSM에서 로드)

---

## ⚠️ Breaking Changes

### 환경 변수 이름 변경

기존에 `SPRING_DATASOURCE_*` 형식을 사용하던 백엔드 코드는 `DB_*` 형식으로 변경해야 합니다.

**마이그레이션:**
- `SPRING_DATASOURCE_URL` → `DB_URL`
- `SPRING_DATASOURCE_USERNAME` → `DB_USERNAME`
- `SPRING_DATASOURCE_PASSWORD` → `DB_PASSWORD`

---

## 👥 기여자

- @gahyun - 환경 변수 통일 및 JDBC URL 수정

---

## 2026-01-24: RDS 데이터베이스 수동 생성 방식으로 변경

### 📋 변경 부분

PostgreSQL Provider를 제거하고, 수동으로 데이터베이스를 생성하는 방식으로 변경했습니다.

**이유:**
- Terraform 실행 환경에서 Private Subnet의 RDS에 접속할 수 없음
- Bastion Host 없이는 PostgreSQL Provider 사용 불가
- 간단한 수동 생성으로 대체 (나중에 Bastion Host 추가 시 자동화 가능)

**비밀번호 저장 정책:**
- **Dev:** SSM Parameter Store만 사용 (무료)
- **Prod:** SSM (DB 비밀번호) + Secrets Manager (JWT Secret, 자동 로테이션용)

---

## 🔧 수정된 파일

### 1. `modules/rds/databases.tf` (삭제)

PostgreSQL Provider를 사용한 자동 데이터베이스 생성 제거

### 2. `modules/rds/provider.tf` (삭제)

PostgreSQL Provider 설정 제거

### 3. `modules/rds/versions.tf` (삭제)

PostgreSQL Provider 버전 설정 제거

### 4. `modules/rds/variables.tf` (수정)

`service_db_passwords` 변수 제거

### 5. `modules/rds/main.tf` (수정)

`publicly_accessible` 설정 제거 (다시 Private으로)

### 6. `modules/security_group/main.tf` (수정)

임시 IP 허용 규칙 제거

### 7. `terraform/environments/dev/main.tf` (수정)

RDS 모듈 호출 시 `service_db_passwords` 전달 제거

### 8. `DB_SETUP_GUIDE.md` (신규 생성)

수동으로 데이터베이스를 생성하는 가이드 문서

---

## 📝 수동 생성 방법

자세한 내용은 `DB_SETUP_GUIDE.md` 참고

### 간단 요약:

1. **ECS Exec로 컨테이너 접속**
2. **psql로 RDS 접속**
3. **5개 데이터베이스 생성** (`unbox_user`, `unbox_product`, `unbox_trade`, `unbox_order`, `unbox_payment`)
4. **5명 사용자 생성** (각 데이터베이스용)
5. **권한 부여**

---

## 🎯 생성되는 리소스

### Dev 환경

**데이터베이스 (5개) - 수동 생성:**
- `unbox_order`
- `unbox_payment`
- `unbox_user`
- `unbox_product`
- `unbox_trade`

**사용자 (5명) - 수동 생성:**
- `unbox_order` (비밀번호: SSM `/unbox/dev/order/DB_PASSWORD`)
- `unbox_payment` (비밀번호: SSM `/unbox/dev/payment/DB_PASSWORD`)
- `unbox_user` (비밀번호: SSM `/unbox/dev/user/DB_PASSWORD`)
- `unbox_product` (비밀번호: SSM `/unbox/dev/product/DB_PASSWORD`)
- `unbox_trade` (비밀번호: SSM `/unbox/dev/trade/DB_PASSWORD`)

**관리자:**
- `unbox_admin` (RDS 마스터 사용자, 모든 데이터베이스 소유)

---

## ⚠️ 주의사항

### 1. 수동 생성 필요

Terraform destroy → apply 시 데이터베이스를 다시 수동으로 생성해야 합니다.

### 2. 비밀번호 관리

- 비밀번호는 Terraform이 자동 생성 (`random_password`)
- SSM Parameter Store에 안전하게 저장
- `lifecycle { ignore_changes = [value] }` 설정으로 변경 방지

### 3. 나중에 자동화

Bastion Host를 추가하면 PostgreSQL Provider를 다시 사용하여 자동화할 수 있습니다.

---

- @gahyun - PostgreSQL Provider 제거 및 수동 생성 가이드 작성

---

## 가현: RDS/Redis 연결 정보 및 Health Check 추가

**변경 사항:**
- Dev/Prod 모두 SSM Parameter Store에 비밀번호 저장
- Prod만 JWT Secret을 Secrets Manager에 추가 저장 (자동 로테이션용)

```hcl
# 1. 공통 시크릿 (JWT Secret 등) - Dev/Prod 모두 SSM 사용
resource "aws_ssm_parameter" "common_secrets" {
  for_each = toset(["JWT_SECRET", "API_ENCRYPTION_KEY"])

  name   = "/${var.project_name}/${var.env}/common/${each.value}"
  type   = "SecureString"
  value  = random_password.rds_password.result 
  key_id = var.kms_key_arn
}

# 2. 서비스별 DB 비밀번호 - Dev/Prod 모두 SSM 사용
resource "aws_ssm_parameter" "service_secrets" {
  for_each = var.service_config

  name   = "/${var.project_name}/${var.env}/${each.key}/DB_PASSWORD"
  type   = "SecureString"
  value  = random_password.service_db_passwords[each.key].result
  key_id = var.kms_key_arn
}

# 3. Prod용 Secrets Manager (JWT Secret - 자동 로테이션용)
resource "aws_secretsmanager_secret" "jwt_secret" {
  count = var.env == "prod" ? 1 : 0
  
  name = "${var.project_name}-${var.env}-jwt-secret"
}
```

### 2. `modules/common/outputs.tf` (수정)

Prod용 JWT Secret ARN output 추가:

```hcl
# Prod용 JWT Secret ARN (ECS 모듈에서 사용)
output "jwt_secret_arn" {
  description = "JWT Secret Secrets Manager ARN (Prod 환경)"
  value       = var.env == "prod" ? aws_secretsmanager_secret.jwt_secret[0].arn : ""
}
```

### 3. `modules/ecs/main.tf` (수정)

ECS Task Definition에서 환경별 Secrets 경로 설정:

```hcl
# Dev: SSM만 사용
secrets = [
  {
    name      = "SPRING_DATASOURCE_PASSWORD"
    valueFrom = "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/${var.project_name}/${var.env}/${each.key}/DB_PASSWORD"
  },
  {
    name      = "SPRING_JWT_SECRET"
    valueFrom = "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/${var.project_name}/${var.env}/common/JWT_SECRET"
  }
]

# Prod: DB는 SSM, JWT는 Secrets Manager
secrets = [
  {
    name      = "SPRING_DATASOURCE_PASSWORD"
    valueFrom = "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/${var.project_name}/${var.env}/${each.key}/DB_PASSWORD"
  },
  {
    name      = "SPRING_JWT_SECRET"
    valueFrom = var.jwt_secret_arn  # Secrets Manager
  }
]
```

### 4. `modules/ecs/variables.tf` (수정)

불필요한 변수 제거:

```hcl
# 제거된 변수:
# - db_password_secret_arns (SSM 사용으로 불필요)

# 남은 변수:
variable "jwt_secret_arn" {
  description = "JWT Secret의 Secrets Manager ARN (Prod 환경)"
  type        = string
  default     = ""  # Dev는 빈 문자열
}
```

### 5. `terraform/environments/dev/main.tf` (수정)

ECS 모듈 호출 시 Secrets 관련 변수 제거:

```hcl
module "ecs" {
  # ...
  
  # Dev 환경: SSM만 사용 (jwt_secret_arn은 prod에서만 필요)
  rds_endpoints = {
    common = module.rds.db_endpoints["common"]
  }
  redis_endpoint = "${module.redis.redis_primary_endpoint}:6379"
}
```

### 6. `terraform/environments/dev/variables.tf` (수정)

불필요한 Secrets Manager ARN 변수 제거 (SSM 사용):

```hcl
# 제거된 변수들:
# - jwt_secret_arn
# - user_db_password_secret_arn
# - product_db_password_secret_arn
# - order_db_password_secret_arn
# - payment_db_password_secret_arn
# - trade_db_password_secret_arn
```

### 5. `modules/rds/versions.tf` (신규 생성)

PostgreSQL Provider 추가:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.22"
    }
  }
}
```

### 6. `modules/rds/provider.tf` (신규 생성)

PostgreSQL Provider 설정:

```hcl
provider "postgresql" {
  alias = "dev"
  
  host     = var.env == "dev" ? aws_db_instance.postgresql["common"].address : null
  port     = 5432
  username = "unbox_admin"
  password = var.db_password
  sslmode  = "require"
  
  connect_timeout = 15
  superuser       = false
}
```

### 7. `modules/rds/databases.tf` (신규 생성)

서비스별 데이터베이스 및 사용자 자동 생성:

```hcl
# 1. 서비스별 데이터베이스 생성 (5개)
resource "postgresql_database" "service_dbs" {
  provider = postgresql.dev
  for_each = var.env == "dev" ? var.service_config : {}
  
  name  = "unbox_${each.key}"  # unbox_order, unbox_payment, ...
  owner = "unbox_admin"
}

# 2. 서비스별 사용자 생성 (5명)
resource "postgresql_role" "service_users" {
  provider = postgresql.dev
  for_each = var.env == "dev" ? var.service_config : {}
  
  name     = "unbox_${each.key}"  # unbox_order, unbox_payment, ...
  login    = true
  password = var.service_db_passwords[each.key]
}

# 3. 권한 부여
resource "postgresql_grant" "service_db_ownership" {
  provider = postgresql.dev
  for_each = var.env == "dev" ? var.service_config : {}
  
  database    = "unbox_${each.key}"
  role        = "unbox_${each.key}"
  object_type = "database"
  privileges  = ["ALL"]
}
```

### 8. `modules/rds/variables.tf` (수정)

서비스별 DB 비밀번호 변수 추가:

```hcl
variable "service_db_passwords" {
  type      = map(string)
  sensitive = true
  default   = {}
}
```

---

## 📝 생성되는 리소스

### Dev 환경

**데이터베이스 (5개):**
- `unbox_order`
- `unbox_payment`
- `unbox_user`
- `unbox_product`
- `unbox_trade`

**사용자 (5명):**
- `unbox_order` (비밀번호: SSM `/unbox/dev/order/DB_PASSWORD`)
- `unbox_payment` (비밀번호: SSM `/unbox/dev/payment/DB_PASSWORD`)
- `unbox_user` (비밀번호: SSM `/unbox/dev/user/DB_PASSWORD`)
- `unbox_product` (비밀번호: SSM `/unbox/dev/product/DB_PASSWORD`)
- `unbox_trade` (비밀번호: SSM `/unbox/dev/trade/DB_PASSWORD`)

**관리자:**
- `unbox_admin` (RDS 마스터 사용자, 모든 데이터베이스 소유)

---

## 🎯 워크플로우

1. **Terraform이 랜덤 비밀번호 생성** (Common 모듈)
   - `random_password.service_db_passwords["order"]` 등 5개 생성

2. **SSM Parameter Store에 저장** (Common 모듈)
   - `/unbox/dev/order/DB_PASSWORD` 등 5개 저장

3. **RDS 인스턴스 생성** (RDS 모듈)
   - `unbox-dev-common-db` (공유 RDS 1개)
   - 마스터 사용자: `unbox_admin`

4. **PostgreSQL Provider로 데이터베이스 생성** (RDS 모듈) ← **신규**
   - `unbox_order`, `unbox_payment` 등 5개 생성

5. **PostgreSQL Provider로 사용자 생성** (RDS 모듈) ← **신규**
   - `unbox_order`, `unbox_payment` 등 5명 생성
   - 각 사용자에게 해당 데이터베이스 권한 부여

6. **ECS Task 실행**
   - SSM에서 비밀번호 자동 로드
   - Spring Boot가 해당 데이터베이스에 접속
   - JPA가 테이블 자동 생성

---

## 📚 사용 예시

### terraform/environments/dev/main.tf

```hcl
module "rds" {
  source = "git::https://github.com/team4-coding-gamja/UNBOX-INFRA.git//modules/rds?ref=main"
  
  project_name       = "unbox"
  env                = "dev"
  private_subnet_ids = module.vpc.private_db_subnet_ids
  availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
  kms_key_arn        = module.common.kms_key_arn
  service_config     = {
    user    = 8081
    product = 8082
    trade   = 8083
    order   = 8084
    payment = 8085
  }
  rds_sg_ids         = module.security_group.rds_sg_ids
  db_password        = data.aws_ssm_parameter.db_password.value
  
  # 서비스별 DB 비밀번호 전달
  service_db_passwords = {
    user    = module.common.service_db_passwords["user"]
    product = module.common.service_db_passwords["product"]
    trade   = module.common.service_db_passwords["trade"]
    order   = module.common.service_db_passwords["order"]
    payment = module.common.service_db_passwords["payment"]
  }
}
```

---

## ⚠️ 주의사항

### 1. PostgreSQL Provider 초기화

Terraform apply 실행 시 PostgreSQL Provider가 RDS에 접속해야 합니다:
- RDS 인스턴스가 먼저 생성되어야 함
- Terraform 실행 환경에서 RDS에 접근 가능해야 함 (VPN, Bastion 등)

### 2. 비밀번호 관리

- 비밀번호는 Terraform이 자동 생성 (`random_password`)
- SSM Parameter Store에 안전하게 저장
- `lifecycle { ignore_changes = [value] }` 설정으로 변경 방지

### 3. Prod 환경

현재는 Dev 환경에만 적용됩니다. Prod 환경은 서비스별 RDS를 사용하므로 별도 설정이 필요합니다.

---

## 🐛 트러블슈팅

### 문제: PostgreSQL Provider 연결 실패

```
Error: error detecting capabilities: error PostgreSQL version: dial tcp: lookup xxx.rds.amazonaws.com: no such host
```

**해결:**
- RDS 인스턴스가 생성되었는지 확인
- Security Group에서 Terraform 실행 환경의 IP 허용
- VPN 또는 Bastion Host를 통해 RDS 접근 가능한지 확인

### 문제: 권한 부족

```
Error: could not create role: pq: permission denied to create role
```

**해결:**
- `unbox_admin` 사용자가 충분한 권한을 가지고 있는지 확인
- RDS 파라미터 그룹에서 `rds.force_ssl = 0` 설정 (필요시)

---

## 👥 기여자

- @gahyun - PostgreSQL Provider 추가 및 자동화 구현

---

## 가현: RDS/Redis 연결 정보 및 Health Check 추가

### 📋 변경 부분

ECS 모듈에 Spring Boot 애플리케이션 실행에 필요한 환경변수와 Health Check를 추가했습니다.

---

## 🔧 수정된 파일

### 1. `modules/ecs/variables.tf`

#### 추가된 변수 (6개)

```hcl
# RDS 엔드포인트 맵
variable "rds_endpoints" {
  description = "각 서비스별 RDS 엔드포인트 맵"
  type        = map(string)
  # 예시: {
  #   user    = "user-db.xxx.rds.amazonaws.com:5432"
  #   product = "product-db.xxx.rds.amazonaws.com:5432"
  # }
}

# Redis 엔드포인트
variable "redis_endpoint" {
  description = "Redis 클러스터 primary 엔드포인트"
  type        = string
  # 예시: "redis.xxx.cache.amazonaws.com:6379"
}

# JWT Secret ARN
variable "jwt_secret_arn" {
  description = "JWT Secret의 Secrets Manager ARN"
  type        = string
  # 예시: "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:jwt-secret-xxx"
}

# DB Password Secret ARN 맵
variable "db_password_secret_arns" {
  description = "각 서비스별 DB 비밀번호 Secret ARN 맵"
  type        = map(string)
  # 예시: {
  #   user    = "arn:aws:secretsmanager:...:secret:user-db-password-xxx"
  #   product = "arn:aws:secretsmanager:...:secret:product-db-password-xxx"
  # }
}

# 컨테이너 이름 suffix 옵션
variable "container_name_suffix" {
  description = "컨테이너 이름에 -service suffix 추가 여부"
  type        = bool
  default     = true
  # true:  user → user-service
  # false: user → user
}

# Health Check 경로
variable "health_check_path" {
  description = "컨테이너 health check 경로"
  type        = string
  default     = "/actuator/health"
}
```

---

### 2. `modules/ecs/main.tf`

#### Task Definition 수정 내역

##### ✅ 컨테이너 이름
```hcl
# 변경 전
name = each.key  # "user"

# 변경 후
name = var.container_name_suffix ? "${each.key}-service" : each.key  # "user-service"
```

##### ✅ 환경변수 추가
```hcl
environment = [
  # 기존
  { name = "SPRING_PROFILES_ACTIVE", value = var.env },
  { name = "KAFKA_BOOTSTRAP_SERVERS", value = var.msk_bootstrap_brokers },
  
  # 추가됨
  { name = "SERVER_PORT", value = tostring(var.service_config[each.key]) },
  
  # RDS 연결 정보 (환경별 분기)
  # dev: 공유 RDS 1개 (모든 서비스가 같은 RDS 서버, 다른 데이터베이스)
  { name = "SPRING_DATASOURCE_URL", value = "jdbc:postgresql://${var.rds_endpoints["shared"]}/unbox_${each.key}" },
  
  # prod: 서비스별 RDS (각 서비스마다 독립된 RDS 서버)
  { name = "SPRING_DATASOURCE_URL", value = "jdbc:postgresql://${var.rds_endpoints[each.key]}/unbox_${each.key}" },
  
  { name = "SPRING_DATASOURCE_USERNAME", value = "unbox_${each.key}" },
  
  # Redis 연결 정보 (dev/prod 모두 공유 Redis 1개)
  { name = "SPRING_REDIS_HOST", value = split(":", var.redis_endpoint)[0] },
  { name = "SPRING_REDIS_PORT", value = "6379" }
]
```

##### ✅ Secrets 수정
```hcl
# dev 환경: Secrets Manager만 사용
secrets = [
  {
    name      = "SPRING_DATASOURCE_PASSWORD"
    valueFrom = var.db_password_secret_arns[each.key]  # Secrets Manager
  },
  {
    name      = "SPRING_JWT_SECRET"
    valueFrom = var.jwt_secret_arn  # Secrets Manager
  }
]

# prod 환경: DB Password는 SSM, JWT는 Secrets Manager
secrets = [
  {
    name      = "SPRING_DATASOURCE_PASSWORD"
    valueFrom = "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/${var.project_name}/${var.env}/${each.key}/DB_PASSWORD"  # SSM Parameter
  },
  {
    name      = "SPRING_JWT_SECRET"
    valueFrom = var.jwt_secret_arn  # Secrets Manager
  }
]
```

##### ✅ Health Check 추가
```hcl
healthCheck = {
  command     = ["CMD-SHELL", "curl -f http://localhost:${var.service_config[each.key]}${var.health_check_path} || exit 1"]
  interval    = 30
  timeout     = 5
  retries     = 3
  startPeriod = 60
}
```

##### ✅ 로그 설정 수정
```hcl
# 변경 전
"awslogs-region" = "ap-northeast-2"  # 하드코딩

# 변경 후
"awslogs-region" = var.aws_region  # 변수 사용
```

#### ECS Service 수정 내역

##### ✅ Load Balancer 컨테이너 이름
```hcl
# 변경 전
container_name = each.key  # "user"

# 변경 후
container_name = var.container_name_suffix ? "${each.key}-service" : each.key  # "user-service"
```

---

## 📝 사용 예시

### 모듈 호출 방법

#### dev 환경 (공유 RDS 1개)

```hcl
module "ecs" {
  source = "git::https://github.com/team4-coding-gamja/UNBOX-INFRA.git//modules/ecs?ref=main"
  
  # 기본 설정
  project_name   = "unbox"
  env            = "dev"
  service_names  = ["user", "product", "trade", "order", "payment"]
  service_config = {
    user    = 8081
    product = 8082
    trade   = 8083
    order   = 8084
    payment = 8085
  }
  
  # RDS: 공유 RDS 1개 (키 이름을 "common"으로)
  rds_endpoints = {
    common = "common-db.xxx.rds.amazonaws.com:5432"
  }
  
  # Redis: 공유 Redis 1개
  redis_endpoint = "redis.xxx.cache.amazonaws.com:6379"
  
  # Secrets (Secrets Manager)
  jwt_secret_arn = "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:jwt-secret-xxx"
  
  db_password_secret_arns = {
    user    = "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:user-db-password-xxx"
    product = "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:product-db-password-xxx"
    trade   = "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:trade-db-password-xxx"
    order   = "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:order-db-password-xxx"
    payment = "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:payment-db-password-xxx"
  }
  
  container_name_suffix = true
  health_check_path     = "/actuator/health"
  
  # 기타 필수 변수들...
}
```

#### prod 환경 (서비스별 RDS 5개)

```hcl
module "ecs" {
  source = "git::https://github.com/team4-coding-gamja/UNBOX-INFRA.git//modules/ecs?ref=main"
  
  # 기본 설정
  project_name   = "unbox"
  env            = "prod"
  service_names  = ["user", "product", "trade", "order", "payment"]
  service_config = {
    user    = 8081
    product = 8082
    trade   = 8083
    order   = 8084
    payment = 8085
  }
  
  # RDS: 서비스별 RDS 5개
  rds_endpoints = {
    user    = "user-db.xxx.rds.amazonaws.com:5432"
    product = "product-db.xxx.rds.amazonaws.com:5432"
    trade   = "trade-db.xxx.rds.amazonaws.com:5432"
    order   = "order-db.xxx.rds.amazonaws.com:5432"
    payment = "payment-db.xxx.rds.amazonaws.com:5432"
  }
  
  # Redis: 공유 Redis 1개
  redis_endpoint = "redis.xxx.cache.amazonaws.com:6379"
  
  # Secrets (Secrets Manager)
  jwt_secret_arn = "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:jwt-secret-xxx"
  
  # prod는 SSM Parameter Store 사용 (모듈 내부에서 자동 처리)
  db_password_secret_arns = {}  # prod에서는 사용 안함
  
  container_name_suffix = true
  health_check_path     = "/actuator/health"
  
  # 기타 필수 변수들...
}
```

---

## 🎯 생성되는 Task Definition 예시

### User Service Task Definition

```json
{
  "family": "unbox-dev-user",
  "cpu": "512",
  "memory": "2048",
  "containerDefinitions": [
    {
      "name": "user-service",
      "image": "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/unbox-dev-user-repo:latest",
      "portMappings": [
        {
          "containerPort": 8081,
          "hostPort": 8081,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "SPRING_PROFILES_ACTIVE",
          "value": "dev"
        },
        {
          "name": "SERVER_PORT",
          "value": "8081"
        },
        {
          "name": "KAFKA_BOOTSTRAP_SERVERS",
          "value": "kafka.xxx:9092"
        },
        {
          "name": "SPRING_DATASOURCE_URL",
          "value": "jdbc:postgresql://user-db.xxx.rds.amazonaws.com:5432/unbox_user"
        },
        {
          "name": "SPRING_DATASOURCE_USERNAME",
          "value": "unbox_user"
        },
        {
          "name": "SPRING_REDIS_HOST",
          "value": "redis.xxx.cache.amazonaws.com"
        },
        {
          "name": "SPRING_REDIS_PORT",
          "value": "6379"
        }
      ],
      "secrets": [
        {
          "name": "SPRING_DATASOURCE_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:user-db-password-xxx"
        },
        {
          "name": "SPRING_JWT_SECRET",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:jwt-secret-xxx"
        }
      ],
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8081/actuator/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/unbox-dev/user",
          "awslogs-region": "ap-northeast-2",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

---

## ⚠️ Breaking Changes

### 1. 필수 변수 추가

다음 변수들이 **필수**로 추가되었습니다:
- `rds_endpoints`
- `redis_endpoint`
- `jwt_secret_arn`
- `db_password_secret_arns`

기존 코드에서 이 모듈을 사용 중이라면 반드시 추가해야 합니다.

### 2. Secrets 형식 변경

**dev 환경:**
- DB Password: Secrets Manager 사용
- JWT Secret: Secrets Manager 사용

**prod 환경:**
- DB Password: SSM Parameter Store 사용 (경로: `/${project_name}/${env}/${service}/DB_PASSWORD`)
- JWT Secret: Secrets Manager 사용

기존에 다른 형식을 사용 중이라면 마이그레이션이 필요합니다.

### 3. 컨테이너 이름 변경

`container_name_suffix = true` (기본값)인 경우:
- 기존: `user`
- 변경: `user-service`

ALB Target Group이나 다른 리소스에서 컨테이너 이름을 참조하는 경우 수정 필요합니다.

---

## 🔄 마이그레이션 가이드

### 1단계: Secrets 준비

#### dev 환경 (Secrets Manager만 사용)

```bash
# JWT Secret 생성
aws secretsmanager create-secret \
  --name unbox-dev-jwt-secret \
  --secret-string "your-jwt-secret-key"

# 각 서비스별 DB Password Secret 생성
for service in user product trade order payment; do
  aws secretsmanager create-secret \
    --name unbox-dev-${service}-db-password \
    --secret-string "your-db-password"
done
```

#### prod 환경 (SSM + Secrets Manager)

```bash
# JWT Secret 생성 (Secrets Manager)
aws secretsmanager create-secret \
  --name unbox-prod-jwt-secret \
  --secret-string "your-jwt-secret-key"

# 각 서비스별 DB Password 생성 (SSM Parameter Store)
for service in user product trade order payment; do
  aws ssm put-parameter \
    --name "/unbox/prod/${service}/DB_PASSWORD" \
    --value "your-db-password" \
    --type "SecureString"
done
```

### 2단계: 모듈 버전 업데이트

```hcl
# terraform init -upgrade 실행
terraform init -upgrade
```

### 3단계: 변수 추가

`main.tf`에 새로운 변수들을 추가합니다. (위의 사용 예시 참고)

### 4단계: 적용

```bash
terraform plan   # 변경 사항 확인
terraform apply  # 적용
```

---

## 📚 참고 사항

### Spring Boot 애플리케이션 설정

이 모듈이 제공하는 환경변수를 사용하려면 Spring Boot `application.yml`에서 다음과 같이 설정하세요:

```yaml
spring:
  datasource:
    url: ${SPRING_DATASOURCE_URL}
    username: ${SPRING_DATASOURCE_USERNAME}
    password: ${SPRING_DATASOURCE_PASSWORD}
  
  redis:
    host: ${SPRING_REDIS_HOST}
    port: ${SPRING_REDIS_PORT}
  
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS}

jwt:
  secret: ${SPRING_JWT_SECRET}

server:
  port: ${SERVER_PORT}
```

### Health Check 엔드포인트

Spring Boot Actuator를 사용하는 경우 `application.yml`에 추가:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health
  endpoint:
    health:
      show-details: always
```

---

## 🐛 알려진 이슈

없음

---
