resource "aws_ecr_repository" "app" {
  name = "${local.project_name}/app"
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = "${aws_ecr_repository.app.name}"

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "selection": {
                "tagStatus": "untagged",
                "countType": "imageCountMoreThan",
                "countNumber": 5
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}
