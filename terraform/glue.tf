resource "aws_glue_catalog_database" "firelens" {
  name = "${local.project_name}-firelens"
}

resource "aws_glue_crawler" "firelens" {
  name          = "${local.project_name}-firelens"
  database_name = aws_glue_catalog_database.firelens.name
  role          = aws_iam_role.glue.arn
  schedule      = "cron(0 0 * * ? *)"

  s3_target {
    path       = "s3://${aws_s3_bucket.firehose.bucket}"
    exclusions = ["error/**"]
  }
}
