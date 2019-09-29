resource "aws_kinesis_firehose_delivery_stream" "firelens" {
  name        = "${local.project_name}-firelens"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = aws_s3_bucket.firehose.arn
    prefix              = "firelens/${local.athena_partition}"
    error_output_prefix = "error/firelens/${local.athena_partition}/!{firehose:error-output-type}"
    compression_format  = "GZIP"

    cloudwatch_logging_options {
      enabled         = "true"
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.firelens.name
    }
  }
}
