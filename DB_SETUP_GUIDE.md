# RDS 데이터베이스 수동 생성 가이드

## 개요

Dev 환경에서는 PostgreSQL Provider를 사용하지 않고, 수동으로 데이터베이스와 사용자를 생성합니다.

## 필요한 정보

### RDS 엔드포인트
```
unbox-dev-common-db.crmw2cqokxc4.ap-northeast-2.rds.amazonaws.com:5432
```

### 마스터 사용자
- Username: `unbox_admin`
- Password: SSM Parameter Store `/unbox/dev/user/DB_PASSWORD`에서 확인

### 생성할 데이터베이스 및 사용자

| 서비스 | 데이터베이스 | 사용자 | 비밀번호 위치 |
|--------|--------------|--------|---------------|
| User | `unbox_user` | `unbox_user` | `/unbox/dev/user/DB_PASSWORD` |
| Product | `unbox_product` | `unbox_product` | `/unbox/dev/product/DB_PASSWORD` |
| Trade | `unbox_trade` | `unbox_trade` | `/unbox/dev/trade/DB_PASSWORD` |
| Order | `unbox_order` | `unbox_order` | `/unbox/dev/order/DB_PASSWORD` |
| Payment | `unbox_payment` | `unbox_payment` | `/unbox/dev/payment/DB_PASSWORD` |

## 생성 방법

### 1. ECS Exec로 컨테이너 접속

```bash
# 실행 중인 Task 찾기
aws ecs list-tasks --cluster unbox-dev-cluster --desired-status RUNNING

# Task에 접속
aws ecs execute-command \
  --cluster unbox-dev-cluster \
  --task <task-arn> \
  --container user \
  --interactive \
  --command "/bin/sh"
```

### 2. psql로 RDS 접속

```bash
# 환경변수 확인
echo $SPRING_DATASOURCE_URL
echo $SPRING_DATASOURCE_USERNAME

# psql 설치 (필요시)
apk add postgresql-client

# RDS 접속
psql -h unbox-dev-common-db.crmw2cqokxc4.ap-northeast-2.rds.amazonaws.com \
     -U unbox_admin \
     -d postgres
```

### 3. 데이터베이스 및 사용자 생성

```sql
-- User 서비스
CREATE DATABASE unbox_user;
CREATE USER unbox_user WITH PASSWORD '<SSM에서 가져온 비밀번호>';
GRANT ALL PRIVILEGES ON DATABASE unbox_user TO unbox_user;
\c unbox_user
GRANT ALL ON SCHEMA public TO unbox_user;
GRANT ALL ON ALL TABLES IN SCHEMA public TO unbox_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO unbox_user;

-- Product 서비스
CREATE DATABASE unbox_product;
CREATE USER unbox_product WITH PASSWORD '<SSM에서 가져온 비밀번호>';
GRANT ALL PRIVILEGES ON DATABASE unbox_product TO unbox_product;
\c unbox_product
GRANT ALL ON SCHEMA public TO unbox_product;
GRANT ALL ON ALL TABLES IN SCHEMA public TO unbox_product;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO unbox_product;

-- Trade 서비스
CREATE DATABASE unbox_trade;
CREATE USER unbox_trade WITH PASSWORD '<SSM에서 가져온 비밀번호>';
GRANT ALL PRIVILEGES ON DATABASE unbox_trade TO unbox_trade;
\c unbox_trade
GRANT ALL ON SCHEMA public TO unbox_trade;
GRANT ALL ON ALL TABLES IN SCHEMA public TO unbox_trade;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO unbox_trade;

-- Order 서비스
CREATE DATABASE unbox_order;
CREATE USER unbox_order WITH PASSWORD '<SSM에서 가져온 비밀번호>';
GRANT ALL PRIVILEGES ON DATABASE unbox_order TO unbox_order;
\c unbox_order
GRANT ALL ON SCHEMA public TO unbox_order;
GRANT ALL ON ALL TABLES IN SCHEMA public TO unbox_order;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO unbox_order;

-- Payment 서비스
CREATE DATABASE unbox_payment;
CREATE USER unbox_payment WITH PASSWORD '<SSM에서 가져온 비밀번호>';
GRANT ALL PRIVILEGES ON DATABASE unbox_payment TO unbox_payment;
\c unbox_payment
GRANT ALL ON SCHEMA public TO unbox_payment;
GRANT ALL ON ALL TABLES IN SCHEMA public TO unbox_payment;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO unbox_payment;
```

### 4. 비밀번호 확인 방법

```bash
# AWS CLI로 SSM Parameter 확인
aws ssm get-parameter --name /unbox/dev/user/DB_PASSWORD --with-decryption --query 'Parameter.Value' --output text
aws ssm get-parameter --name /unbox/dev/product/DB_PASSWORD --with-decryption --query 'Parameter.Value' --output text
aws ssm get-parameter --name /unbox/dev/trade/DB_PASSWORD --with-decryption --query 'Parameter.Value' --output text
aws ssm get-parameter --name /unbox/dev/order/DB_PASSWORD --with-decryption --query 'Parameter.Value' --output text
aws ssm get-parameter --name /unbox/dev/payment/DB_PASSWORD --with-decryption --query 'Parameter.Value' --output text
```

## 확인

```sql
-- 데이터베이스 목록 확인
\l

-- 사용자 목록 확인
\du

-- 특정 데이터베이스 접속 테스트
\c unbox_user unbox_user
```

## 주의사항

1. 비밀번호는 SSM Parameter Store에서 가져와야 합니다
2. 각 사용자는 해당 데이터베이스에만 접근 권한이 있습니다
3. Spring Boot JPA가 테이블을 자동으로 생성하므로, 데이터베이스만 생성하면 됩니다
4. 나중에 Bastion Host를 추가하면 이 과정을 자동화할 수 있습니다
