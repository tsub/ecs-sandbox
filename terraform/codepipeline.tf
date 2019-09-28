resource "aws_codepipeline" "deployment" {
  name     = "${local.project_name}-deployment"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline-deployment-artifact.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "ecr-source"
      category         = "Source"
      owner            = "AWS"
      provider         = "ECR"
      version          = "1"
      output_artifacts = ["app"]

      configuration = {
        RepositoryName = aws_ecr_repository.app.name
        ImageTag       = "latest"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["app"]
      output_artifacts = ["imagedefinitions"]
      version          = "1"

      configuration = {
        ProjectName   = aws_codebuild_project.deployment.name
        PrimarySource = "source_code"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["imagedefinitions"]

      configuration = {
        ClusterName = aws_ecs_cluster.main.name
        ServiceName = aws_ecs_service.app.name
      }
    }
  }
}
