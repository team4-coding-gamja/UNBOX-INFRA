#!/bin/bash
ACCOUNT_ID="632941626317"
REGION="ap-northeast-2"
SERVICES=("user" "product" "order" "payment" "trade")

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

for svc in "${SERVICES[@]}"; do
  echo "Processing $svc service"
  
  # 주소 변수 설정
  DEV_IMG="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/unbox-dev-$svc-repo:latest"
  PROD_IMG="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/unbox-prod-$svc-repo:latest"

  echo "  Pulling (AMD64)"
  docker pull --platform linux/amd64 $DEV_IMG
  
  echo "  Retagging"
  docker tag $DEV_IMG $PROD_IMG
  
  echo "  Pushing"
  docker push $PROD_IMG
  
  echo "$svc done"
  echo "-------------------------------------"
done