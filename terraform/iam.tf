# ECS Task Execution Role

data "aws_iam_policy_document" "ecs" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs-task-execution" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "ecs-task-execution" {
  name               = "${local.project_name}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs.json
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution" {
  role       = aws_iam_role.ecs-task-execution.name
  policy_arn = aws_iam_policy.ecs-task-execution.arn
}

resource "aws_iam_policy" "ecs-task-execution" {
  name   = "${local.project_name}-ecs-task-execution"
  policy = data.aws_iam_policy_document.ecs-task-execution.json
}

# Kinesis Data Firehose

data "aws_iam_policy_document" "firehose" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

data "aws_iam_policy_document" "firehose-to-s3" {
  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject"
    ]

    resources = [
      aws_s3_bucket.firehose.arn,
      "${aws_s3_bucket.firehose.arn}/*"
    ]
  }

  statement {
    actions = [
      "logs:PutLogEvents"
    ]

    resources = [aws_cloudwatch_log_group.firehose.arn]
  }

  statement {
    actions = [
      "lambda:InvokeFunction",
      "lambda:GetFunctionConfiguration"
    ]

    resources = ["${aws_lambda_function.json-parse.arn}:*"]
  }
}

resource "aws_iam_role" "firehose" {
  name               = "${local.project_name}-firehose"
  assume_role_policy = data.aws_iam_policy_document.firehose.json
}

resource "aws_iam_role_policy_attachment" "firehose" {
  role       = aws_iam_role.firehose.name
  policy_arn = aws_iam_policy.firehose-to-s3.arn
}

resource "aws_iam_policy" "firehose-to-s3" {
  name   = "${local.project_name}-firehose-to-s3"
  policy = data.aws_iam_policy_document.firehose-to-s3.json
}

# Glue

data "aws_iam_policy_document" "glue" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue" {
  name               = "${local.project_name}-glue"
  assume_role_policy = data.aws_iam_policy_document.glue.json
}

resource "aws_iam_role_policy_attachment" "glue" {
  role       = aws_iam_role.glue.name
  policy_arn = aws_iam_policy.glue.arn
}

resource "aws_iam_policy" "glue" {
  name = "${local.project_name}-glue"

  # See https://docs.aws.amazon.com/glue/latest/dg/create-service-policy.html
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "glue:*",
                "s3:GetBucketLocation",
                "s3:ListBucket",
                "s3:ListAllMyBuckets",
                "s3:GetBucketAcl",
                "ec2:DescribeVpcEndpoints",
                "ec2:DescribeRouteTables",
                "ec2:CreateNetworkInterface",
                "ec2:DeleteNetworkInterface",				
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVpcAttribute",
                "iam:ListRolePolicies",
                "iam:GetRole",
                "iam:GetRolePolicy",
                "cloudwatch:PutMetricData"                
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:CreateBucket"
            ],
            "Resource": [
                "arn:aws:s3:::aws-glue-*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"				
            ],
            "Resource": [
                "arn:aws:s3:::aws-glue-*/*",
                "arn:aws:s3:::*/*aws-glue-*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::crawler-public*",
                "arn:aws:s3:::aws-glue-*",
                "${aws_s3_bucket.firehose.arn}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:AssociateKmsKey"                
            ],
            "Resource": [
                "arn:aws:logs:*:*:/aws-glue/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags",
                "ec2:DeleteTags"
            ],
            "Condition": {
                "ForAllValues:StringEquals": {
                    "aws:TagKeys": [
                        "aws-glue-service-resource"
                    ]
                }
            },
            "Resource": [
                "arn:aws:ec2:*:*:network-interface/*",
                "arn:aws:ec2:*:*:security-group/*",
                "arn:aws:ec2:*:*:instance/*"
            ]
        }
    ]
}
EOF
}

# Lambda

data "aws_iam_policy_document" "lambda" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda-logs" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.project_name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda.json
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda-logs.arn
}

resource "aws_iam_policy" "lambda-logs" {
  name   = "${local.project_name}-lambda-logs"
  policy = data.aws_iam_policy_document.lambda-logs.json
}
