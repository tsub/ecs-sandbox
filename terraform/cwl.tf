resource "aws_cloudwatch_log_group" "ecs-container-insights" {
  name              = "/aws/ecs/containerinsights/${aws_ecs_cluster.main.name}/performance"
  retention_in_days = 1 # fixed from ECS
}
