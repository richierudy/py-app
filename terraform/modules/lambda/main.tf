# Lambda function for deployment notifications
resource "aws_lambda_function" "deployment_notifier" {
  filename      = "lambda_deployment.zip"
  function_name = "${var.environment}-${var.app_name}-deployment-notifier"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30

  environment {
    variables = {
      ENVIRONMENT = var.environment
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.environment}-${var.app_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# EventBridge rule for ECS deployment events
resource "aws_cloudwatch_event_rule" "ecs_deployment" {
  name        = "${var.environment}-${var.app_name}-ecs-deployment"
  description = "Capture ECS deployment events"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Deployment State Change"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.ecs_deployment.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.deployment_notifier.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.deployment_notifier.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecs_deployment.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.deployment_notifier.function_name
}
