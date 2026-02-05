resource "aws_lb" "this" {
  name               = "${var.project_name}-${var.env}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  access_logs {
    bucket  = var.logs_bucket_id
    prefix  = "alb-logs"
    enabled = true
  }

  enable_deletion_protection = false

  tags = { Name = "${var.project_name}-${var.env}-alb" }
}

resource "aws_lb_target_group" "services" {
  for_each = var.service_config

  name_prefix = "${substr(each.key, 0, 5)}-"
  port        = 8080 # All containers use port 8080 internally
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  # Dev 환경에서는 빠른 배포를 위해 30초, Prod는 300초 (기본값)
  deregistration_delay = var.env == "prod" ? 300 : 30

  health_check {
    enabled             = true
    path                = "/${each.key}/actuator/health"
    port                = 8080
    healthy_threshold   = 3
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 1. HTTP Listener (80)
# - HTTPS 인증서가 있으면: HTTPS로 리다이렉트 (Prod)
# - HTTPS 인증서가 없으면: 404 반환 (Dev - 혹은 Dev도 HTTP 트래픽 허용한다면 forward로 해야 함. 여기서는 일단 Prod HTTPS 강제화를 가정)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response" # 기본값 (데드엔드)

    fixed_response {
      content_type = "text/plain"
      message_body = "404: Not Found"
      status_code  = "404"
    }
  }
}

# HTTP -> HTTPS 리다이렉트 규칙 (인증서가 있을 때만 생성)
resource "aws_lb_listener_rule" "http_to_https" {
  count = var.enable_https ? 1 : 0

  listener_arn = aws_lb_listener.http.arn
  priority     = 100 # 가장 낮은 우선순위 (마지막에 걸리도록)

  action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}

# 2. HTTPS Listener (443) - 인증서가 있을 때만 생성
resource "aws_lb_listener" "https" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: Not Found"
      status_code  = "404"
    }
  }
}

# 3. 서비스별 라우팅 규칙
resource "aws_lb_listener_rule" "services" {
  for_each = var.service_config

  # 인증서가 있으면 HTTPS 리스너에, 없으면 HTTP 리스너에 붙임
  listener_arn = var.enable_https ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  priority     = 10 + index(keys(var.service_config), each.key)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  condition {
    path_pattern {
      values = ["/${each.key}/*"]
    }
  }
}
