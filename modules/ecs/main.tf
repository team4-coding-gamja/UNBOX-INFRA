# 1. ECS 클러스터
resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-${var.env}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# 3. 서비스별 로그 그룹
resource "aws_cloudwatch_log_group" "services" {
  for_each = toset(var.service_names)
  name     = "/ecs/${var.project_name}-${var.env}/${each.key}"
  retention_in_days = 7
}

# 4. ECS Task Definition (설계도)
resource "aws_ecs_task_definition" "services" {
  for_each = toset(var.service_names)

  family                   = "${var.project_name}-${var.env}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 2048
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = "public.ecr.aws/nginx/nginx:latest" #
      #image     = "${aws_ecr_repository.services[each.key].repository_url}:latest"
      essential = true
      portMappings = [
        {
          # containerPort = var.service_config[each.key]
          # hostPort      = var.service_config[each.key]
          containerPort = 80
        
        # 2. 외부(ALB)에서 찔러주는 포트 (Fargate 호스트 레벨 매핑)
          hostPort      = 80
          
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "SPRING_PROFILES_ACTIVE", value = var.env },
        { name = "KAFKA_BOOTSTRAP_SERVERS", value = var.msk_bootstrap_brokers }
      ]
      
      # [수정] ARN을 변수 처리하여 유연하게 변경
      secrets = var.env == "prod" ? [
        {
          name      = "DB_PASSWORD"
          # data.aws_caller_identity.current.account_id를 쓰면 계정번호 자동 매칭 가능
          valueFrom = "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:unbox/prod/${each.key}-secrets:password::"
        }
      ] : [
        {
          name      = "DB_PASSWORD"
          valueFrom = "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/unbox/dev/${each.key}/DB_PASSWORD"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services[each.key].name
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# 5. ECS 서비스 (실행기) - 수정본
resource "aws_ecs_service" "services" {
  for_each = toset(var.service_names)

  name            = "${var.project_name}-${var.env}-${each.key}"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # [중요] 타겟 그룹 변경 시 서비스 재생성이 필요할 수 있으므로 강제 교체 설정 추가 (선택)
  force_new_deployment = true

  network_configuration {
    subnets          = var.env == "dev" ? [var.app_subnet_ids[0]] : var.app_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arns[each.key]
    container_name   = each.key
    # ★ 수정 전: container_port = var.service_config[each.key]
    # ★ 수정 후: 80 (Task Definition의 containerPort와 반드시 일치해야 함)
    container_port   = 80 
  }
}