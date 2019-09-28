resource "aws_s3_bucket" "codepipeline-deployment-artifact" {
  bucket        = "${local.project_name}-codepipeline-deployment-artifact"
  force_destroy = true
}
