resource "aws_s3_bucket" "firehose" {
  bucket        = "${local.project_name}-firehose"
  force_destroy = true
}
