# 1. ECS 클러스터
resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-${var.env}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# 2. ECR 경로 가져오기
data "aws_ecr_repository" "service_ecr" {
  for_each = var.service_config
  name = "${var.project_name}-${var.env}-${each.key}-repo"
}

# 3. 서비스별 로그 그룹
resource "aws_cloudwatch_log_group" "services" {
  for_each = toset(var.service_names)
  name     = "/ecs/${var.project_name}-${var.env}/${each.key}"
  retention_in_days = 7
  kms_key_id        = var.kms_key_arn
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
      name      = var.container_name_suffix ? "${each.key}-service" : each.key
      image     = "${data.aws_ecr_repository.service_ecr[each.key].repository_url}:${lookup(var.image_tags, each.key, "latest")}"
      essential = true
      portMappings = [
        {
          containerPort = var.service_config[each.key]
          hostPort      = var.service_config[each.key]
          name          = "http"
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "SPRING_PROFILES_ACTIVE", value = var.env },
        { name = "SERVER_PORT", value = tostring(var.service_config[each.key]) },
        { name = "KAFKA_BOOTSTRAP_SERVERS", value = var.msk_bootstrap_brokers },
        
        # [환경별 로직] RDS 연결 정보
        # dev: 공유 RDS 1개 사용 (모든 서비스가 같은 RDS, 다른 DB)
        # prod: 서비스별 RDS 사용
        { 
          name  = "SPRING_DATASOURCE_URL"
          value = "jdbc:postgresql://${var.env == "dev" ? var.rds_endpoints["common"] : var.rds_endpoints[each.key]}/unbox_${each.key}"
        },
        { name = "SPRING_DATASOURCE_USERNAME", value = "unbox_${each.key}" },
        { name = "DB_DRIVER_CLASS_NAME", value = "org.postgresql.Driver" },
        
        # Redis 연결 정보 (dev/prod 모두 공유 Redis 1개 사용)
        { name = "SPRING_REDIS_HOST", value = split(":", var.redis_endpoint)[0] },
        { name = "SPRING_REDIS_PORT", value = "6379" }
      ]
      
      # [환경별 로직] Secrets 설정
      # dev: Secrets Manager만 사용
      # prod: DB Password는 SSM, JWT는 Secrets Manager
      secrets = var.env == "prod" ? [
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/${var.project_name}/${var.env}/${each.key}/DB_PASSWORD"
        },
        {
          name      = "SPRING_JWT_SECRET"
          valueFrom = var.jwt_secret_arn
        }
      ] : [
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = var.db_password_secret_arns[each.key]
        },
        {
          name      = "SPRING_JWT_SECRET"
          valueFrom = var.jwt_secret_arn
        }
      ]
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.service_config[each.key]}${var.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services[each.key].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# 5. ECS 서비스 (실행기)
resource "aws_ecs_service" "services" {
  for_each = toset(var.service_names)

  name            = "${var.project_name}-${var.env}-${each.key}"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true

  # 타겟 그룹 변경 시 서비스 재생성을 위한 설정
  force_new_deployment = true

  service_connect_configuration {
    enabled   = true
    namespace = var.cloud_map_namespace_arn

    service {
      port_name      = "http"
      discovery_name = each.key
      client_alias {
        port     = 80
        dns_name = "${each.key}.${var.project_name}.local"
      }
    }
  }
  network_configuration {
    subnets          = var.env == "dev" ? [var.app_subnet_ids[0]] : var.app_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arns[each.key]
    container_name   = var.container_name_suffix ? "${each.key}-service" : each.key
    container_port   = var.service_config[each.key]
  }
  
}