resource "aws_lb" "main" {
  name               = local.project_name
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.wildcard.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = ""
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_rule" "app" {
  listener_arn = aws_lb_listener.https.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    field  = "host-header"
    values = [aws_route53_record.app.name]
  }
}

resource "aws_lb_target_group" "app" {
  lifecycle {
    create_before_destroy = true
  }

  # Workaround for error that "name_prefix" cannot be longer than 6 characters
  name_prefix = "app-"

  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = module.vpc.vpc_id
  target_type          = "ip"
  deregistration_delay = 60

  health_check {
    path     = "/healthz"
    port     = 8080
    protocol = "HTTP"
    matcher  = "200"
  }
}
