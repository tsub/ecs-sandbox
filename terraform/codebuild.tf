data "local_file" "deployment" {
  filename = "${path.module}/codebuild/deployment.yml"
}

resource "aws_codebuild_project" "deployment" {
  name         = "${local.project_name}-deployment"
  service_role = aws_iam_role.codebuild.arn

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:1.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = data.local_file.deployment.content
  }

  artifacts {
    type = "CODEPIPELINE"
  }
}
