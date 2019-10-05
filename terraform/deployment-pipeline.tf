# CodeBuild

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

# CodePipeline

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

# S3

resource "aws_s3_bucket" "codepipeline-deployment-artifact" {
  bucket        = "${local.project_name}-codepipeline-deployment-artifact"
  force_destroy = true
}

# CloudWatch Logs

resource "aws_cloudwatch_log_group" "codebuild-deployment" {
  name              = "/aws/codebuild/${aws_codebuild_project.deployment.name}"
  retention_in_days = local.log_retention_in_days
}


# CloudWatch Events

resource "aws_cloudwatch_event_rule" "ecr-source" {
  name = "${local.project_name}-ecr-source"

  event_pattern = <<EOF
{
  "source": [
    "aws.ecr"
  ],
  "detail": {
    "eventName": [
      "PutImage"
    ],
    "requestParameters": {
      "repositoryName": [
        "${aws_ecr_repository.app.name}"
      ],
      "imageTag": [
        "latest"
      ]
    }
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "deployment" {
  rule     = aws_cloudwatch_event_rule.ecr-source.name
  arn      = aws_codepipeline.deployment.arn
  role_arn = aws_iam_role.codepipeline-execution.arn
}

# IAM

## CloudWatch Events Target

data "aws_iam_policy_document" "cwe" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codepipeline-execution" {
  statement {
    actions   = ["codepipeline:StartPipelineExecution"]
    resources = [aws_codepipeline.deployment.arn]
  }
}

resource "aws_iam_role" "codepipeline-execution" {
  name               = "${local.project_name}-codepipeline-execution"
  assume_role_policy = data.aws_iam_policy_document.cwe.json
}

resource "aws_iam_role_policy_attachment" "codepipeline-execution" {
  role       = aws_iam_role.codepipeline-execution.name
  policy_arn = aws_iam_policy.codepipeline-execution.arn
}

resource "aws_iam_policy" "codepipeline-execution" {
  name   = "${local.project_name}-codepipeline-execution"
  policy = data.aws_iam_policy_document.codepipeline-execution.json
}

## CodePipeline

data "aws_iam_policy_document" "codepipeline" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "${local.project_name}-codepipeline"
  assume_role_policy = data.aws_iam_policy_document.codepipeline.json
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.codepipeline.arn
}

resource "aws_iam_policy" "codepipeline" {
  name = "${local.project_name}-codepipeline"

  # See https://docs.aws.amazon.com/codepipeline/latest/userguide/how-to-custom-role.html
  policy = <<EOF
{
    "Statement": [
        {
            "Action": [
                "iam:PassRole"
            ],
            "Resource": "*",
            "Effect": "Allow",
            "Condition": {
                "StringEqualsIfExists": {
                    "iam:PassedToService": [
                        "cloudformation.amazonaws.com",
                        "elasticbeanstalk.amazonaws.com",
                        "ec2.amazonaws.com",
                        "ecs-tasks.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Action": [
                "codecommit:CancelUploadArchive",
                "codecommit:GetBranch",
                "codecommit:GetCommit",
                "codecommit:GetUploadArchiveStatus",
                "codecommit:UploadArchive"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "codedeploy:CreateDeployment",
                "codedeploy:GetApplication",
                "codedeploy:GetApplicationRevision",
                "codedeploy:GetDeployment",
                "codedeploy:GetDeploymentConfig",
                "codedeploy:RegisterApplicationRevision"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "elasticbeanstalk:*",
                "ec2:*",
                "elasticloadbalancing:*",
                "autoscaling:*",
                "cloudwatch:*",
                "s3:*",
                "sns:*",
                "cloudformation:*",
                "rds:*",
                "sqs:*",
                "ecs:*"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "lambda:InvokeFunction",
                "lambda:ListFunctions"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "opsworks:CreateDeployment",
                "opsworks:DescribeApps",
                "opsworks:DescribeCommands",
                "opsworks:DescribeDeployments",
                "opsworks:DescribeInstances",
                "opsworks:DescribeStacks",
                "opsworks:UpdateApp",
                "opsworks:UpdateStack"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "cloudformation:CreateStack",
                "cloudformation:DeleteStack",
                "cloudformation:DescribeStacks",
                "cloudformation:UpdateStack",
                "cloudformation:CreateChangeSet",
                "cloudformation:DeleteChangeSet",
                "cloudformation:DescribeChangeSet",
                "cloudformation:ExecuteChangeSet",
                "cloudformation:SetStackPolicy",
                "cloudformation:ValidateTemplate"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "codebuild:BatchGetBuilds",
                "codebuild:StartBuild"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Effect": "Allow",
            "Action": [
                "devicefarm:ListProjects",
                "devicefarm:ListDevicePools",
                "devicefarm:GetRun",
                "devicefarm:GetUpload",
                "devicefarm:CreateUpload",
                "devicefarm:ScheduleRun"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "servicecatalog:ListProvisioningArtifacts",
                "servicecatalog:CreateProvisioningArtifact",
                "servicecatalog:DescribeProvisioningArtifact",
                "servicecatalog:DeleteProvisioningArtifact",
                "servicecatalog:UpdateProduct"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudformation:ValidateTemplate"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:DescribeImages"
            ],
            "Resource": "*"
        }
    ],
    "Version": "2012-10-17"
}
EOF
}

## CodeBuild

data "aws_iam_policy_document" "codebuild" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${local.project_name}-codebuild"
  assume_role_policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  role       = aws_iam_role.codebuild.name
  policy_arn = aws_iam_policy.codebuild.arn
}

resource "aws_iam_policy" "codebuild" {
  name = "${local.project_name}-codebuild"

  # See https://docs.aws.amazon.com/codebuild/latest/userguide/setting-up.html#setting-up-service-role
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchLogsPolicy",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Sid": "CodeCommitPolicy",
      "Effect": "Allow",
      "Action": [
        "codecommit:GitPull"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Sid": "S3GetObjectPolicy",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Sid": "S3PutObjectPolicy",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Sid": "S3BucketIdentity",
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketAcl",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}
