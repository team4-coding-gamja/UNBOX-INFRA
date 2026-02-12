#!/bin/bash
set -e

echo "🚀 [Step 1] Deleting Kubernetes Ingress & Services (to clean up ALBs)..."
# Ingress 삭제 (ALB 제거 트리거)
kubectl delete ingress --all --all-namespaces --timeout=60s || echo "⚠️  Ingress delete failed or empty"

# LoadBalancer Service 삭제 (NLB 제거 트리거)
kubectl delete svc --all --all-namespaces --field-selector spec.type=LoadBalancer --timeout=60s || echo "⚠️  Service delete failed or empty"

echo "⏳ Waiting for AWS Load Balancers to be deleted (30s)..."
sleep 30

echo "🔍 Checking for residual ALBs..."
REMAINING_ALBS=$(aws elbv2 describe-load-balancers --region ap-northeast-2 --query "LoadBalancers[?contains(LoadBalancerName, 'k8s')].LoadBalancerArn" --output text)

if [ -n "$REMAINING_ALBS" ]; then
  echo "⚠️  Found orphaned ALBs! Force deleting..."
  for arn in $REMAINING_ALBS; do
    echo "🔥 Deleting ALB: $arn"
    aws elbv2 delete-load-balancer --load-balancer-arn "$arn"
  done
else
  echo "✅ No orphaned ALBs found."
fi

echo "🚀 [Step 2] Running Terraform Destroy..."
cd terraform/environments/dev
terraform destroy -auto-approve

echo "✅ Infrastructure destroy complete!"
