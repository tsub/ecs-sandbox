data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "template_file" "task-definition-app" {
  template = file("${path.module}/task_definitions/app.json")

  vars = {
    app_image          = aws_ecr_repository.app.repository_url
    app_log_group_name = aws_cloudwatch_log_group.app.name
    app_log_region     = data.aws_region.current.name
  }
}

data "aws_ecs_task_definition" "app" {
  task_definition = "${aws_ecs_task_definition.app.family}"
}

resource "aws_ecs_cluster" "main" {
  name = local.project_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.project_name}-app"
  container_definitions    = data.template_file.task-definition-app.rendered
  requires_compatibilities = ["FARGATE"]
  cpu                      = 0.25 * 1024
  memory                   = 512
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.app.arn
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
