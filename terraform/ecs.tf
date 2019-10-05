resource "aws_ecs_cluster" "main" {
  name = local.project_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
