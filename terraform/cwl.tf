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
