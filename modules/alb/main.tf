resource "aws_lb" "this" {
  name               = "${var.project_name}-${var.env}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = { Name = "${var.project_name}-${var.env}-alb" }
}

resource "aws_lb_target_group" "services" {
  for_each = var.service_config
  
  name_prefix = "${substr(each.key, 0, 5)}-"
  port        = 8080  # All containers use port 8080 internally
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  # Dev 환경에서는 빠른 배포를 위해 30초, Prod는 300초 (기본값)
  deregistration_delay = var.env == "prod" ? 300 : 30

  health_check {
    enabled             = true
    path                = "/${each.key}/actuator/health"
    port                = "traffic-port"
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

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "services" {
  for_each = var.service_config

  listener_arn = aws_lb_listener.http.arn
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