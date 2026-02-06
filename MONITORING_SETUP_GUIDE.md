# 📊 모니터링 설정 가이드

## 개요

UNBOX 프로젝트의 모니터링 스택:
- **Prometheus**: 메트릭 수집 및 저장
- **Grafana**: 시각화 및 대시보드
- **AlertManager**: 알림 관리
- **Discord**: 알림 채널

## 환경별 구성

### Local 환경
```
✅ Prometheus (메트릭 수집)
✅ Grafana (시각화)
❌ AlertManager (알림 없음)
❌ Discord (알림 없음)
```

**접근 방법:**
- Grafana: `http://localhost:3000`
- 계정: `admin` / `admin`

### Dev 환경
```
✅ Prometheus (메트릭 수집)
✅ Grafana (시각화)
✅ AlertManager (알림)
✅ Discord (#dev-alerts 채널)
```

**접근 방법:**
- Grafana: AWS LoadBalancer URL
- 계정: `admin` / `dev-admin-password`

### Prod 환경
```
✅ Prometheus (메트릭 수집, HA 모드)
✅ Grafana (시각화, HA 모드)
✅ AlertManager (알림, HA 모드)
✅ Discord (#prod-alerts 채널)
```

**접근 방법:**
- Grafana: AWS LoadBalancer URL (HTTPS)
- 계정: `admin` / `prod-secure-password-change-me`

---

## 1. Discord Webhook 설정

### 1.1 Discord 채널 생성

**Dev 환경:**
1. Discord 서버에서 `#dev-alerts` 채널 생성
2. 채널 설정 → 연동 → Webhook 생성
3. Webhook URL 복사

**Prod 환경:**
1. Discord 서버에서 `#prod-alerts` 채널 생성
2. 채널 설정 → 연동 → Webhook 생성
3. Webhook URL 복사

### 1.2 Kubernetes Secret 업데이트

```bash
# Dev 환경
kubectl create secret generic discord-webhook \
  --from-literal=dev-webhook-url="https://discord.com/api/webhooks/YOUR_DEV_WEBHOOK_ID/YOUR_DEV_WEBHOOK_TOKEN" \
  --namespace=unbox-monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

# Prod 환경
kubectl create secret generic discord-webhook \
  --from-literal=prod-webhook-url="https://discord.com/api/webhooks/YOUR_PROD_WEBHOOK_ID/YOUR_PROD_WEBHOOK_TOKEN" \
  --namespace=unbox-monitoring \
  --dry-run=client -o yaml | kubectl apply -f -
```

또는 파일 직접 수정:
```bash
# Dev
vim UNBOX-INFRA/gitops/infra/prometheus/alertmanager-discord.yaml
# dev-webhook-url 값 변경

# Prod
vim UNBOX-INFRA/gitops/infra/prometheus/alertmanager-discord.yaml
# prod-webhook-url 값 변경
```

---

## 2. 배포

### 2.1 Local 환경 (k3d)

```bash
# 1. Prometheus + Grafana 배포
kubectl apply -f UNBOX-INFRA/gitops/infra/prometheus/application-local.yaml

# 2. 대시보드 ConfigMap 생성
kubectl apply -f UNBOX-INFRA/gitops/infra/grafana/dashboards-configmap.yaml

# 3. 배포 확인
kubectl get pods -n unbox-monitoring

# 4. Grafana 접속
# 브라우저에서 http://localhost:3000
# 계정: admin / admin
```

### 2.2 Dev 환경 (AWS EKS)

```bash
# 1. Discord Webhook Secret 생성 (위 1.2 참고)

# 2. AlertManager Discord 어댑터 배포
kubectl apply -f UNBOX-INFRA/gitops/infra/prometheus/alertmanager-discord.yaml

# 3. Prometheus + Grafana 배포
kubectl apply -f UNBOX-INFRA/gitops/infra/prometheus/application-dev.yaml

# 4. Alert Rules 배포
kubectl apply -f UNBOX-INFRA/gitops/infra/grafana/alerts/argocd-alerts.yaml
kubectl apply -f UNBOX-INFRA/gitops/infra/grafana/alerts/rollout-alerts.yaml
kubectl apply -f UNBOX-INFRA/gitops/infra/grafana/alerts/performance-alerts.yaml

# 5. 대시보드 ConfigMap 생성
kubectl apply -f UNBOX-INFRA/gitops/infra/grafana/dashboards-configmap.yaml

# 6. LoadBalancer URL 확인
kubectl get svc -n unbox-monitoring prometheus-grafana
```

### 2.3 Prod 환경 (AWS EKS)

```bash
# Dev와 동일하지만 application-prod.yaml 사용
kubectl apply -f UNBOX-INFRA/gitops/infra/prometheus/application-prod.yaml

# ⚠️ Prod는 HTTPS 설정 필요
# application-prod.yaml에서 ACM 인증서 ARN 변경:
# service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:..."
```

---

## 3. 대시보드 구성

### 3.1 System Overview
**용도:** 전체 시스템 상태 한눈에 파악

**주요 메트릭:**
- 전체 서비스 상태 (Running/Down)
- 전체 요청 수 (RPS)
- 전체 에러율
- 평균 응답 시간 (P95)
- 서비스별 요청 수
- 서비스별 에러율
- CPU/메모리 사용률
- Kafka Consumer Lag
- 데이터베이스 연결 풀

**접근:**
- Grafana → Dashboards → System Overview

### 3.2 Deployment Monitoring (핵심!)
**용도:** 배포 전략 모니터링 및 자동 롤백 추적

**주요 메트릭:**
- ArgoCD Sync 상태 (Synced/OutOfSync)
- ArgoCD Health 상태 (Healthy/Degraded)
- 활성 Rollout 수
- Canary 가중치 (실시간)
- **Canary Pod 에러율** (자동 롤백 트리거)
- **Canary Pod 성공률** (자동 롤백 트리거)
- **Canary Pod 응답 시간** (성능 비교)
- 배포 타임라인

**접근:**
- Grafana → Dashboards → Deployment Monitoring

**중요:**
- Canary 분석 시 이 대시보드를 실시간으로 확인
- 에러율 5% 초과 또는 성공률 95% 미만 시 자동 롤백

### 3.3 Service Details
**용도:** 특정 서비스 상세 분석

**주요 메트릭:**
- 서비스별 요청 수 (RPS)
- 서비스별 에러율
- 서비스별 응답 시간 (P50/P90/P95/P99)
- HTTP 상태 코드 분포
- CPU/메모리 사용률
- JVM Heap 사용률
- GC 시간
- 데이터베이스 연결 풀
- 데이터베이스 쿼리 시간

**접근:**
- Grafana → Dashboards → Service Details
- 상단에서 서비스 선택 (드롭다운)

---

## 4. 알림 규칙

### 4.1 ArgoCD 알림

| 알림 | 조건 | 심각도 | 설명 |
|------|------|--------|------|
| ArgoCD Sync 시작 | Sync Running | cd | 배포 시작 알림 |
| ArgoCD Sync 성공 | Sync Succeeded | cd | 배포 완료 알림 |
| ArgoCD Sync 실패 | Sync Failed > 1분 | cd | 배포 실패 알림 |
| ArgoCD App Degraded | Degraded > 5분 | warning | 애플리케이션 비정상 |
| ArgoCD App OutOfSync | OutOfSync > 10분 | warning | Git과 불일치 |

### 4.2 Rollout 알림

| 알림 | 조건 | 심각도 | 설명 |
|------|------|--------|------|
| Rollout 시작 | Phase Progressing | cd | Canary/Blue-Green 시작 |
| Canary 분석 중 | Canary 진행 중 | cd | Canary Pod 분석 중 |
| Rollout 자동 롤백 | Phase Degraded | critical | 자동 롤백 발생 |
| Rollout 완료 | Phase Healthy | cd | 배포 성공 |
| Rollout 중단 | Paused > 5분 | warning | 수동 승인 필요 |
| Canary 에러율 높음 | 에러율 > 5% (2분) | critical | 자동 롤백 트리거 |
| Canary 성공률 낮음 | 성공률 < 95% (2분) | critical | 자동 롤백 트리거 |
| Canary 응답 느림 | P95 > 1초 (3분) | warning | 성능 저하 |

### 4.3 성능 알림

| 알림 | 조건 | 심각도 | 설명 |
|------|------|--------|------|
| 높은 에러율 | 에러율 > 5% (5분) | critical | 서비스 에러 급증 |
| 느린 응답 시간 | P95 > 2초 (5분) | warning | 응답 시간 느림 |
| 높은 CPU 사용률 | CPU > 80% (10분) | warning | CPU 부족 |
| 높은 메모리 사용률 | Memory > 80% (10분) | warning | 메모리 부족 |
| Pod 재시작 빈번 | 재시작 > 3회/시간 | warning | Pod 불안정 |
| Pod CrashLoopBackOff | CrashLoop > 5분 | critical | Pod 시작 실패 |
| DB 연결 실패 | DB 에러 > 0 (2분) | critical | 데이터베이스 문제 |
| Kafka Consumer Lag | Lag > 1000 (5분) | warning | 메시지 처리 지연 |
| 디스크 공간 부족 | 여유 < 20% (10분) | warning | 디스크 부족 |

---

## 5. Discord 알림 예시

### 5.1 CD 알림 (파란색)

```
🚀 CD 이벤트

환경: DEV
서비스: trade-service
이벤트: Rollout 시작
전략: Canary
시간: 2026-02-06 14:30:00
```

### 5.2 Canary 분석 중 (파란색)

```
🔍 Canary 분석 중

환경: DEV
서비스: trade-service
현재 가중치: 25%
에러율: 2.3% (임계값: 5%)
성공률: 97.5% (임계값: 95%)
응답시간 P95: 0.8초
상태: 정상 - 다음 단계 진행 중
```

### 5.3 자동 롤백 (빨간색)

```
🔄 자동 롤백 발생

환경: PROD
서비스: payment-service
이유: Canary 에러율 높음
에러율: 8.2% (임계값: 5%)
성공률: 91.8% (임계값: 95%)
조치: 자동으로 이전 버전으로 롤백 완료
시간: 2026-02-06 15:45:00
```

### 5.4 배포 완료 (초록색)

```
✅ 배포 완료

환경: PROD
서비스: order-service
전략: Blue-Green
소요 시간: 10분 30초
최종 상태: Healthy
시간: 2026-02-06 16:00:00
```

---

## 6. 메트릭 수집 설정

### 6.1 Spring Boot Actuator

각 서비스의 `application.yml`:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}
      environment: ${ENVIRONMENT:local}
```

### 6.2 Prometheus Annotations

각 서비스의 Deployment/Rollout에 자동으로 추가됨:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/actuator/prometheus"
```

### 6.3 Canary Pod 분리 측정

Argo Rollouts가 자동으로 `rollouts-pod-template-hash` 라벨 추가:

```yaml
labels:
  rollouts-pod-template-hash: "7d9c8b5f4"  # Canary Pod
  rollouts-pod-template-hash: ""           # Stable Pod
```

Prometheus 쿼리에서 이 라벨로 Canary Pod만 필터링:

```promql
# Canary Pod만
http_requests_total{rollouts_pod_template_hash!=""}

# Stable Pod만
http_requests_total{rollouts_pod_template_hash=""}
```

---

## 7. 트러블슈팅

### 7.1 Grafana 접속 안 됨 (Local)

```bash
# Pod 상태 확인
kubectl get pods -n unbox-monitoring

# LoadBalancer 확인
kubectl get svc -n unbox-monitoring prometheus-grafana

# k3d에서 포트 포워딩 확인
k3d cluster list
```

### 7.2 Discord 알림 안 옴

```bash
# AlertManager Discord 어댑터 로그 확인
kubectl logs -n unbox-monitoring deployment/alertmanager-discord

# Secret 확인
kubectl get secret discord-webhook -n unbox-monitoring -o yaml

# AlertManager 설정 확인
kubectl get configmap -n unbox-monitoring
```

### 7.3 메트릭 수집 안 됨

```bash
# Prometheus Targets 확인
# Grafana → Configuration → Data Sources → Prometheus → Explore
# 쿼리: up{namespace=~"unbox-.*"}

# Service Monitor 확인
kubectl get servicemonitor -n unbox-monitoring

# Pod Annotations 확인
kubectl get pod -n unbox-local -o yaml | grep prometheus
```

### 7.4 Canary 메트릭 안 보임

```bash
# Rollout 상태 확인
kubectl get rollout -n unbox-dev

# Pod 라벨 확인
kubectl get pods -n unbox-dev --show-labels | grep rollouts-pod-template-hash

# Prometheus 쿼리 테스트
# Grafana → Explore
# 쿼리: http_requests_total{rollouts_pod_template_hash!=""}
```

---

## 8. 유지보수

### 8.1 Prometheus 데이터 보관 기간 변경

```yaml
# application-{env}.yaml 수정
prometheus:
  prometheusSpec:
    retention: 30d  # 원하는 기간으로 변경
```

### 8.2 Alert 임계값 조정

```yaml
# alerts/*.yaml 수정
- alert: High_Error_Rate
  expr: |
    ... > 5  # 임계값 변경
  for: 5m    # 지속 시간 변경
```

### 8.3 대시보드 커스터마이징

1. Grafana UI에서 대시보드 수정
2. 우측 상단 → Share → Export → Save to file
3. JSON 파일을 `dashboards/` 폴더에 저장
4. ConfigMap 업데이트:
   ```bash
   kubectl create configmap grafana-dashboards \
     --from-file=dashboards/ \
     --namespace=unbox-monitoring \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

---

## 9. 참고 자료

- [Prometheus 공식 문서](https://prometheus.io/docs/)
- [Grafana 공식 문서](https://grafana.com/docs/)
- [Argo Rollouts Metrics](https://argoproj.github.io/argo-rollouts/features/analysis/)
- [ArgoCD Metrics](https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/)
- [Spring Boot Actuator](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)

---

## 10. 체크리스트

### Local 환경
- [ ] Prometheus 배포 완료
- [ ] Grafana 접속 가능 (http://localhost:3000)
- [ ] 대시보드 3개 로드 확인
- [ ] 메트릭 수집 확인 (System Overview 대시보드)

### Dev 환경
- [ ] Discord Webhook 설정 완료
- [ ] AlertManager Discord 어댑터 배포
- [ ] Prometheus + Grafana 배포 완료
- [ ] Alert Rules 배포 완료
- [ ] 대시보드 3개 로드 확인
- [ ] Discord 알림 테스트 완료

### Prod 환경
- [ ] Discord Webhook 설정 완료 (#prod-alerts)
- [ ] HTTPS 인증서 설정 완료
- [ ] Prometheus + Grafana 배포 완료 (HA 모드)
- [ ] Alert Rules 배포 완료
- [ ] 대시보드 3개 로드 확인
- [ ] Discord 알림 테스트 완료
- [ ] 수동 승인 프로세스 테스트 완료
