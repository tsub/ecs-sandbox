data "aws_iam_policy_document" "app" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "app-ecr" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]

    resources = [aws_ecr_repository.app.arn]
  }
}

data "aws_iam_policy_document" "app-awslogs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [aws_cloudwatch_log_group.app.arn]
  }
}

resource "aws_iam_role" "app" {
  name               = "${local.project_name}-app"
  assume_role_policy = data.aws_iam_policy_document.app.json
}

resource "aws_iam_role_policy_attachment" "app-ecr" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app-ecr.arn
}

resource "aws_iam_role_policy_attachment" "app-awslogs" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app-awslogs.arn
}

resource "aws_iam_policy" "app-ecr" {
  name   = "${local.project_name}-app-ecr"
  policy = data.aws_iam_policy_document.app-ecr.json
}

resource "aws_iam_policy" "app-awslogs" {
  name   = "${local.project_name}-app-awslogs"
  policy = data.aws_iam_policy_document.app-awslogs.json
}
