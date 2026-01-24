# ECS 모듈 업데이트 내역

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

## 👥 기여자

- @gahyun - ECS 모듈 개선

---

## 📞 문의

이슈나 질문이 있으면 GitHub Issues에 등록해주세요.
