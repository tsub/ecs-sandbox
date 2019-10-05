resource "aws_cloudwatch_log_group" "log-router" {
  name              = "/ecs/${aws_ecs_cluster.main.name}/${local.project_name}-log-router"
  retention_in_days = local.log_retention_in_days
}

resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${local.project_name}"
  retention_in_days = local.log_retention_in_days
}

resource "aws_cloudwatch_log_stream" "firelens" {
  name           = "firelens"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}

resource "aws_cloudwatch_log_group" "ecs-container-insights" {
  name              = "/aws/ecs/containerinsights/${aws_ecs_cluster.main.name}/performance"
  retention_in_days = 1 # fixed from ECS
}

resource "aws_cloudwatch_log_group" "lambda-json-parse" {
  name              = "/aws/lambda/${aws_lambda_function.json-parse.function_name}"
  retention_in_days = local.log_retention_in_days
}
