# ECS

resource "aws_ecs_cluster" "main" {
  name = local.project_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# VPC

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.15.0"

  name = local.project_name
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true # Cost cutting (false is preferred for production use)

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Security Group

resource "aws_security_group" "elb" {
  name   = "${local.project_name}-elb"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ELB

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

# ACM

resource "aws_acm_certificate" "wildcard" {
  domain_name       = "*.${local.route53_zone}"
  validation_method = "DNS"
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [aws_route53_record.wildcard-validation.fqdn]
}

# Route53

data "aws_route53_zone" "main" {
  name = local.route53_zone
}

resource "aws_route53_record" "wildcard-validation" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = aws_acm_certificate.wildcard.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.wildcard.domain_validation_options.0.resource_record_type
  ttl     = "300"

  records = [aws_acm_certificate.wildcard.domain_validation_options.0.resource_record_value]
}

# CloudWatch Logs

resource "aws_cloudwatch_log_group" "ecs-container-insights" {
  name              = "/aws/ecs/containerinsights/${aws_ecs_cluster.main.name}/performance"
  retention_in_days = 1 # fixed from ECS
}

# IAM

## ECS Task Execution Role

data "aws_iam_policy_document" "ecs" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs-task-execution" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "ecs-task-execution" {
  name               = "${local.project_name}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs.json
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution" {
  role       = aws_iam_role.ecs-task-execution.name
  policy_arn = aws_iam_policy.ecs-task-execution.arn
}

resource "aws_iam_policy" "ecs-task-execution" {
  name   = "${local.project_name}-ecs-task-execution"
  policy = data.aws_iam_policy_document.ecs-task-execution.json
}
