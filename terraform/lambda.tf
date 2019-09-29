data "archive_file" "json-parse" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/json-parse"
  output_path = "${path.module}/lambda/json-parse.zip"
}

resource "aws_lambda_function" "json-parse" {
  filename         = data.archive_file.json-parse.output_path
  function_name    = "${local.project_name}-json-parse"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs10.x"
  source_code_hash = filebase64sha256(data.archive_file.json-parse.output_path)
  publish          = "true"
  timeout          = 300
}

resource "aws_lambda_permission" "json-parse" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.json-parse.function_name
  principal     = "firehose.amazonaws.com"
  source_arn    = aws_kinesis_firehose_delivery_stream.firelens.arn
}
