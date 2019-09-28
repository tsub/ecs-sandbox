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
