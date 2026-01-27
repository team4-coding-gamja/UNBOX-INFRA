# Lambda 함수용 IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.env}-log-notifier-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda 기본 실행 권한
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda 함수 코드 압축
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/discord_notifier.py"
  output_path = "${path.module}/lambda/discord_notifier.zip"
}

# Lambda 함수
resource "aws_lambda_function" "log_notifier" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-${var.env}-log-notifier"
  role            = aws_iam_role.lambda_role.arn
  handler         = "discord_notifier.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30

  environment {
    variables = {
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
    }
  }

  tags = {
    Name = "${var.project_name}-${var.env}-log-notifier"
  }
}

# Lambda 함수 로그 그룹
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.log_notifier.function_name}"
  retention_in_days = 7
  kms_key_id        = var.kms_key_arn
}

# CloudWatch Logs가 Lambda를 호출할 수 있는 권한
resource "aws_lambda_permission" "allow_cloudwatch" {
  for_each = toset(var.service_names)

  statement_id  = "AllowExecutionFromCloudWatch-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_notifier.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/ecs/${var.project_name}-${var.env}/${each.key}:*"
}

# CloudWatch Logs Subscription Filter (ERROR/WARNING 감지)
resource "aws_cloudwatch_log_subscription_filter" "error_warning_filter" {
  for_each = toset(var.service_names)

  name            = "${var.project_name}-${var.env}-${each.key}-error-warning-filter"
  log_group_name  = "/ecs/${var.project_name}-${var.env}/${each.key}"
  filter_pattern  = "?ERROR ?WARN ?WARNING ?Exception ?exception"
  destination_arn = aws_lambda_function.log_notifier.arn

  depends_on = [aws_lambda_permission.allow_cloudwatch]
}
