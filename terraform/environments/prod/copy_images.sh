#!/bin/bash
ACCOUNT_ID="632941626317"
REGION="ap-northeast-2"
SERVICES=("user" "product" "order" "payment" "trade")

# ECR 로그인
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

for svc in "${SERVICES[@]}"; do
  echo "🚀 Processing $svc service..."
  
  # 주소 변수 설정
  DEV_IMG="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/unbox-dev-$svc-repo:latest"
  PROD_IMG="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/unbox-prod-$svc-repo:latest"

  # [수정된 부분] --platform 옵션 추가 (Mac에서도 강제로 서버용 이미지를 받음)
  echo "   ... Pulling (AMD64)"
  docker pull --platform linux/amd64 $DEV_IMG
  
  echo "   ... Retagging"
  docker tag $DEV_IMG $PROD_IMG
  
  echo "   ... Pushing"
  docker push $PROD_IMG
  
  echo "✅ $svc done!"
  echo "-------------------------------------"
done