resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${aws_ecs_cluster.main.name}/${local.project_name}-app"
  retention_in_days = 7
}
