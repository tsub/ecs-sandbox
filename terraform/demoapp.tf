# ECS

data "template_file" "task-definition-app" {
  template = file("${path.module}/task_definitions/app.json")

  vars = {
    app_image                 = aws_ecr_repository.app.repository_url
    app_log_region            = data.aws_region.current.name
    app_log_stream_name       = aws_kinesis_firehose_delivery_stream.firelens.name
    log_router_image          = "906394416424.dkr.ecr.ap-northeast-1.amazonaws.com/aws-for-fluent-bit:latest"
    log_router_log_region     = data.aws_region.current.name
    log_router_log_group_name = aws_cloudwatch_log_group.log-router.name
  }
}

data "aws_ecs_task_definition" "app" {
  task_definition = "${aws_ecs_task_definition.app.family}"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.project_name}-app"
  container_definitions    = data.template_file.task-definition-app.rendered
  requires_compatibilities = ["FARGATE"]
  cpu                      = 0.25 * 1024
  memory                   = 512
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs-task-execution.arn
  task_role_arn            = aws_iam_role.ecs-task-app.arn
}

resource "aws_ecs_service" "app" {
  name            = "${local.project_name}-app"
  cluster         = aws_ecs_cluster.main.id
  task_definition = "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:task-definition/${aws_ecs_task_definition.app.family}:${max("${aws_ecs_task_definition.app.revision}", "${data.aws_ecs_task_definition.app.revision}")}"
  launch_type     = "FARGATE"
  desired_count   = 3

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 8080
  }

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.app.id]
  }
}

# ECR

resource "aws_ecr_repository" "app" {
  name = "${local.project_name}/app"
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = "${aws_ecr_repository.app.name}"

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "selection": {
                "tagStatus": "untagged",
                "countType": "imageCountMoreThan",
                "countNumber": 5
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

# ELB

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

# Route53

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "app.${local.route53_zone}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Security Group

resource "aws_security_group" "app" {
  name   = "${local.project_name}-app"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = [aws_security_group.elb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# IAM

## ECS Task Role

data "aws_iam_policy_document" "ecs-task-app" {
  statement {
    actions = [
      "firehose:DeleteDeliveryStream",
      "firehose:PutRecord",
      "firehose:PutRecordBatch",
      "firehose:UpdateDestination"
    ]

    resources = [aws_kinesis_firehose_delivery_stream.firelens.arn]
  }
}

resource "aws_iam_role" "ecs-task-app" {
  name               = "${local.project_name}-ecs-task-app"
  assume_role_policy = data.aws_iam_policy_document.ecs.json
}

resource "aws_iam_role_policy_attachment" "ecs-task-app" {
  role       = aws_iam_role.ecs-task-app.name
  policy_arn = aws_iam_policy.ecs-task-app.arn
}

resource "aws_iam_policy" "ecs-task-app" {
  name   = "${local.project_name}-ecs-task-app"
  policy = data.aws_iam_policy_document.ecs-task-app.json
}

