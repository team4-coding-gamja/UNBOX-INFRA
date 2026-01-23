# 1. ECS Task Execution Role (관리소장님: 컨테이너 실행 및 환경 구축용)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-${var.env}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# 1-1. 기본 실행 권한 (ECR 이미지 가져오기, CloudWatch 기본 로그)
resource "aws_iam_role_policy_attachment" "ecs_task_execution_standard" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 1-2. [핵심] KMS 복호화 및 SSM 파라미터 읽기 권한
# DB 비밀번호 등을 복호화해서 컨테이너에 넣어줄 때 사용합니다.
resource "aws_iam_role_policy" "ecs_execution_prod_secrets" {
  name = "${var.project_name}-${var.env}-execution-secrets-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "kms:Decrypt",
          "ssm:GetParameters",
          "secretsmanager:GetSecretValue" # 시크릿 매니저 값을 읽기 위한 한 줄 추가
        ]
        Resource = [
          var.kms_key_arn,
          "arn:aws:ssm:ap-northeast-2:*:parameter/unbox/*",
          "arn:aws:secretsmanager:ap-northeast-2:*:secret:unbox/prod/*" # prod 시크릿 경로 제한
        ]
      }
    ]
  })
}

# ---------------------------------------------------------

# 2. ECS Task Role (입주민: 우리 앱 서비스 로직이 직접 쓰는 권한)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-${var.env}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# 2-1. ECS Exec(내부 접속) 및 CloudWatch 커스텀 메트릭 권한
resource "aws_iam_role_policy" "ecs_task_custom" {
  name = "${var.project_name}-${var.env}-task-custom-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------

# 3. CloudTrail 로그 전송용 역할
resource "aws_iam_role" "cloudtrail_to_cloudwatch" {
  name = "${var.project_name}-${var.env}-cloudtrail-to-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch_policy" {
  name = "${var.project_name}-${var.env}-cloudtrail-policy"
  role = aws_iam_role.cloudtrail_to_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

###########################################################
# 1. 공통 데이터 소스 및 로컬 변수
###########################################################
# 현재 활성화된 SSO 인스턴스 정보 가져오기 (콘솔에서 활성화 선행 필요)
data "aws_ssoadmin_instances" "this" {}

# 현재 실행 중인 AWS 계정 ID 자동 참조
data "aws_caller_identity" "current" {}

locals {
  instance_arn = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  store_id     = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
  account_id   = data.aws_caller_identity.current.account_id

  # 실무 패턴: 관리할 사용자 명단 (리스트 형식)
  users = var.users
}

###########################################################
# 2. 권한 세트 (Permission Set) - "무엇을 할 수 있는가?"
###########################################################
# 관리자 권한 세트 (실무형 이름 규칙: ps-***)
resource "aws_ssoadmin_permission_set" "admin" {
  name             = "ps-admin-access"
  description      = "Administrator Access for dev environment"
  instance_arn     = local.instance_arn
  session_duration = "PT8H" # 실무 권장: 8시간 세션
}

# AWS 관리형 정책 연결 (AdministratorAccess)
resource "aws_ssoadmin_managed_policy_attachment" "admin_attach" {
  instance_arn       = local.instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
}

###########################################################
# 3. 그룹 및 사용자 관리 - "누가 누구인가?"
###########################################################
# 실무 권장: 관리자 그룹 생성 (개인이 아닌 그룹에 권한 부여를 위함)
resource "aws_identitystore_group" "admins" {
  identity_store_id = local.store_id
  display_name      = "aws-admins-group"
  description       = "Group for users with full admin access"
}

# 사용자 생성기 (for_each를 사용하여 명단만큼 자동 생성)
resource "aws_identitystore_user" "users" {
  for_each          = var.users
  identity_store_id = local.store_id

  user_name    = each.value.user_name
  display_name = each.value.display

  emails {
    value = each.value.user_name
    primary = true
  }

  name {
    given_name  = each.value.given_name
    family_name = each.value.family_name
  }
}

# 사용자 -> 그룹 연결 (신규 유저를 어드민 그룹에 포함)
resource "aws_identitystore_group_membership" "admin_members" {
  for_each          = aws_identitystore_user.users
  identity_store_id = local.store_id
  group_id          = aws_identitystore_group.admins.group_id
  member_id         = each.value.user_id
}

###########################################################
# 4. 계정 할당 (Account Assignment) - "누가 어디에 접속하는가?"
###########################################################
# 최종 단계: 그룹(GROUP) 단위로 계정에 권한 할당
resource "aws_ssoadmin_account_assignment" "admin_assign" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn

  principal_id   = aws_identitystore_group.admins.group_id
  principal_type = "GROUP" # 실무 표준: 개별 유저가 아닌 그룹으로 관리

  target_id   = local.account_id
  target_type = "AWS_ACCOUNT"
}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "github_actions_ecr" {
  name = "github-actions-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringLike = {
          # 특정 레포지토리에서만 이 역할을 쓸 수 있게 제한 (중요!)
          "token.actions.githubusercontent.com:sub" = "repo:team4-coding-gamja/UNBOX-BE:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_power_user" {
  role       = aws_iam_role.github_actions_ecr.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}