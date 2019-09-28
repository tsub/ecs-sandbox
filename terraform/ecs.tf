resource "aws_ecs_cluster" "main" {
  name = local.project_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.project_name}-app"
  container_definitions    = "${file("task_definitions/app.json")}"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 0.25 * 1024
  memory                   = 512
  network_mode             = "awsvpc"
}

resource "aws_ecs_service" "app" {
  name            = "${local.project_name}-app"
  cluster         = "${aws_ecs_cluster.main.id}"
  task_definition = "${aws_ecs_task_definition.app.arn}"
  launch_type     = "FARGATE"
  desired_count   = 3

  load_balancer {
    target_group_arn = "${aws_lb_target_group.app.arn}"
    container_name   = "app"
    container_port   = 80
  }

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.app.id]
  }
}
