data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_apigatewayv2_api" "websocket_api" {
  name                       = "websocket-api-test"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_stage" "example_stage" {
  api_id = aws_apigatewayv2_api.websocket_api.id
  name   = "example-stage"
  default_route_settings {
    data_trace_enabled     = true
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
  }
}

resource "aws_dynamodb_table" "job_connections_table" {
  name         = "jobs-websocket-connections"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "connectionId"

  attribute {
    name = "connectionId"
    type = "S"
  }

  attribute {
    name = "clientId"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  global_secondary_index {
    name            = "clientIdIndex"
    hash_key        = "clientId"
    projection_type = "ALL"
  }
}

resource "aws_iam_role" "jobs_api_role" {
  name = "jobs_api_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "my_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:GetRecords",
            "dynamodb:DeleteItem",
            "dynamodb:PutItem",
            "dynamodb:Query",
            "dynamodb:Scan",
            "dynamodb:UpdateItem"
          ],
          "Resource" : aws_dynamodb_table.job_connections_table.arn
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "execute-api:ManageConnections"
          ],
          "Resource" : [
            "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.websocket_api.arn}/${aws_apigatewayv2_stage.example_stage.name}/POST/@connections/*"
          ]
        }
      ]
    })
  }
}

data "archive_file" "jobs_api_lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/dist/jobs.zip"
  source_dir  = "${path.module}/../src"
}

# could do with one lambda and routing

resource "aws_lambda_function" "listen" {
  filename      = "${path.module}/dist/jobs.zip"
  function_name = "jobs-api-listen"
  role          = aws_iam_role.jobs_api_role.arn
  handler       = "listen.handler"
  runtime       = "nodejs16.x"

  environment {
    variables = {
      API_ENDPOINT          = aws_apigatewayv2_api.websocket_api.api_endpoint
      CONNECTION_TABLE_NAME = aws_dynamodb_table.job_connections_table.name
    }
  }
}

resource "aws_lambda_function" "disconnect" {
  filename      = "${path.module}/dist/jobs.zip"
  function_name = "jobs-api-disconnect"
  role          = aws_iam_role.jobs_api_role.arn
  handler       = "disconnect.handler"
  runtime       = "nodejs16.x"

  environment {
    variables = {
      API_ENDPOINT          = aws_apigatewayv2_api.websocket_api.api_endpoint
      CONNECTION_TABLE_NAME = aws_dynamodb_table.job_connections_table.name
    }
  }
}

resource "aws_lambda_function" "notify" {
  filename      = "${path.module}/dist/jobs.zip"
  function_name = "jobs-api-notify"
  role          = aws_iam_role.jobs_api_role.arn
  handler       = "notify.handler"
  runtime       = "nodejs16.x"

  environment {
    variables = {
      API_ENDPOINT          = aws_apigatewayv2_api.websocket_api.api_endpoint
      CONNECTION_TABLE_NAME = aws_dynamodb_table.job_connections_table.name
    }
  }
}

resource "aws_lambda_permission" "listen" {
  statement_id  = "invoke-listen"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.listen.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket_api.execution_arn}/${aws_apigatewayv2_stage.example_stage.name}/*"
}

resource "aws_lambda_permission" "disconnect" {
  statement_id  = "invoke-disconnect"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.disconnect.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket_api.execution_arn}/${aws_apigatewayv2_stage.example_stage.name}/*"
}

resource "aws_lambda_permission" "notify" {
  statement_id  = "invoke-notify"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notify.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket_api.execution_arn}/${aws_apigatewayv2_stage.example_stage.name}/*"
}

resource "aws_apigatewayv2_integration" "disconnect" {
  api_id                    = aws_apigatewayv2_api.websocket_api.id
  integration_type          = "AWS"
  connection_type           = "INTERNET"
  content_handling_strategy = "CONVERT_TO_TEXT"
  description               = "listen"
  integration_method        = "POST"
  integration_uri           = aws_lambda_function.listen.invoke_arn
  passthrough_behavior      = "WHEN_NO_MATCH"
}

resource "aws_apigatewayv2_integration" "notify" {
  api_id                    = aws_apigatewayv2_api.websocket_api.id
  integration_type          = "AWS"
  connection_type           = "INTERNET"
  content_handling_strategy = "CONVERT_TO_TEXT"
  description               = "listen"
  integration_method        = "POST"
  integration_uri           = aws_lambda_function.listen.invoke_arn
  passthrough_behavior      = "WHEN_NO_MATCH"
}

resource "aws_apigatewayv2_integration" "listen" {
  api_id                    = aws_apigatewayv2_api.websocket_api.id
  integration_type          = "AWS"
  connection_type           = "INTERNET"
  content_handling_strategy = "CONVERT_TO_TEXT"
  description               = "listen"
  integration_method        = "POST"
  integration_uri           = aws_lambda_function.listen.invoke_arn
  passthrough_behavior      = "WHEN_NO_MATCH"
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.disconnect.id}"
}

resource "aws_apigatewayv2_route" "notify" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "listen"
  target    = "integrations/${aws_apigatewayv2_integration.notify.id}"
}

resource "aws_apigatewayv2_route" "listen" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.listen.id}"
}

resource "aws_apigatewayv2_deployment" "example" {
  api_id      = aws_apigatewayv2_api.websocket_api.id
  description = "Example deployment"

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_apigatewayv2_route.disconnect,
    aws_apigatewayv2_route.notify,
    aws_apigatewayv2_route.listen
  ]
}


output "connection_table_arn" {
  value = aws_dynamodb_table.job_connections_table.arn
}

output "gateway_uri" {
  description = "The WSS Protocol URI to connect to"
  #value       = "wss://${aws_apigatewayv2_api.websocket_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_apigatewayv2_stage.example_stage.name}"
  value = aws_apigatewayv2_stage.example_stage.invoke_url
}

