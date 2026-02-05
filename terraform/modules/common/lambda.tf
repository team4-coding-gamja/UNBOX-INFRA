# AWS에서 제공하는 검증된 "RDS-PostgreSQL Rotation" 애플리케이션 배포
# (Source: AWS Serverless Application Repository)
resource "aws_serverlessapplicationrepository_cloudformation_stack" "rds_rotation" {
  count = var.env == "prod" ? 1 : 0 # 비용 절감을 위해 PROD만 적용

  name           = "${var.project_name}-${var.env}-rds-rotation-stack"
  application_id = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSPostgreSQLRotationSingleUser"

  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_RESOURCE_POLICY",
  ]

  parameters = {
    endpoint            = "https://secretsmanager.ap-northeast-2.amazonaws.com"
    functionName        = "${var.project_name}-${var.env}-rds-rotation-lambda"
    vpcSubnetIds        = join(",", var.private_app_subnet_ids)
    vpcSecurityGroupIds = var.app_sg_ids["user"] # 임시로 user 앱 SG 사용 (RDS 접근 가능하므로)
  }
}

# (주의: 위 SAR 앱은 내부적으로 IAM Role을 만들 수도 있습니다. 
# 하지만 우리가 만든 Role을 쓰려면 SAR 대신 직접 Lambda 리소스를 정의해야 합니다.
# 여기서는 SAR의 편리함을 선택하고, 파라미터로 제어합니다.)
