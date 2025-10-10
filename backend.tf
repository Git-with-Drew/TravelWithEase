# DynamoDB table for storing contact form submissions
resource "aws_dynamodb_table" "contact_form_submissions" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name            = "EmailIndex"
    hash_key        = "email"
    projection_type = "ALL"
  }

  tags = {
    Name        = "TravelContactTable"
    Environment = var.environment
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "TravelWithEase_lambda_role"

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

# IAM Policy for Lambda to access DynamoDB and SES
resource "aws_iam_policy" "lambda_policy" {
  name        = "TravelWithEase_lambda_policy"
  description = "IAM policy for Lambda to access DynamoDB and SES"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = [
          aws_dynamodb_table.contact_form_submissions.arn,
          "${aws_dynamodb_table.contact_form_submissions.arn}/index/*"
        ]
      },
      {
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "lambda_role_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}


# Automatically package Lambda function before deployment
resource "null_resource" "package_lambda" {
  triggers = {
    # Repackage when any of these files change
    index_js      = filemd5("${path.module}/lambda/index.js")
    package_json  = filemd5("${path.module}/lambda/package.json")
  }

  provisioner "local-exec" {
    command = "bash package_lambda.sh"
    working_dir = "${path.module}/lambda"
    
  }
}

# Data source to read the packaged Lambda zip
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda/contact_form_lambda.zip"
  
  excludes = [
    "package_lambda.sh",
    "build.sh",
    "*.md",
    "README*",
    ".git*",
    "*.log",
    "package-lock.json"
  ]

  depends_on = [null_resource.package_lambda]
}

# Lambda function to handle contact form submissions
resource "aws_lambda_function" "contact_form_handler" {
  function_name = "TravelWithEase_ContactFormHandler"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = data.archive_file.lambda_zip.output_path # Output path for the Lambda zip file
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256 # Ensures Lambda updates and is redeployed when zip content changes
  timeout       = 30
  memory_size   = 512

  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.contact_form_submissions.name
      FROM_EMAIL     = var.ses_sender_email
      BUSINESS_EMAIL = var.ses_recipient_email
    }
  }

  tags = {
    Name        = "TravelContactLambda"
    Environment = var.environment
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_role_attachment]
}

# API Gateway Rest API
resource "aws_api_gateway_rest_api" "contact_form_api" {
  name        = "TravelWithEase_ContactFormAPI"
  description = "API Gateway for handling contact form submissions"

  tags = {
    Name        = "TravelContactAPI"
    Environment = var.environment
  }
}

# API Gateway Resource
resource "aws_api_gateway_resource" "contact_form_resource" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  parent_id   = aws_api_gateway_rest_api.contact_form_api.root_resource_id
  path_part   = "submit"
}

# API Gateway POST Method
resource "aws_api_gateway_method" "contact_form_post" {
  rest_api_id   = aws_api_gateway_rest_api.contact_form_api.id
  resource_id   = aws_api_gateway_resource.contact_form_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# OPTIONS Method for CORS
resource "aws_api_gateway_method" "contact_form_options" {
  rest_api_id   = aws_api_gateway_rest_api.contact_form_api.id
  resource_id   = aws_api_gateway_resource.contact_form_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Lambda Integration for POST
resource "aws_api_gateway_integration" "contact_form_integration" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  resource_id = aws_api_gateway_resource.contact_form_resource.id
  http_method = aws_api_gateway_method.contact_form_post.http_method
  type        = "AWS_PROXY"
  integration_http_method = "POST"
  uri         = aws_lambda_function.contact_form_handler.invoke_arn
}

# CORS Integration for OPTIONS
resource "aws_api_gateway_integration" "contact_form_cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  resource_id = aws_api_gateway_resource.contact_form_resource.id
  http_method = aws_api_gateway_method.contact_form_options.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# Method Response for POST
resource "aws_api_gateway_method_response" "contact_form_post_response" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  resource_id = aws_api_gateway_resource.contact_form_resource.id
  http_method = aws_api_gateway_method.contact_form_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

# Method Response for OPTIONS
resource "aws_api_gateway_method_response" "contact_form_options_response" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  resource_id = aws_api_gateway_resource.contact_form_resource.id
  http_method = aws_api_gateway_method.contact_form_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

# Integration Response for OPTIONS (CORS) - Only needed for MOCK integration
resource "aws_api_gateway_integration_response" "contact_form_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  resource_id = aws_api_gateway_resource.contact_form_resource.id
  http_method = aws_api_gateway_method.contact_form_options.http_method
  status_code = aws_api_gateway_method_response.contact_form_options_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
  }

  depends_on = [aws_api_gateway_integration.contact_form_cors_integration]
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gateway_lambda_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_form_handler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.contact_form_api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "contact_form_deployment" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.contact_form_resource.id,
      aws_api_gateway_method.contact_form_post.id,
      aws_api_gateway_method.contact_form_options.id,
      aws_api_gateway_integration.contact_form_integration.id,
      aws_api_gateway_integration.contact_form_cors_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.contact_form_integration,
    aws_api_gateway_integration.contact_form_cors_integration,
    aws_api_gateway_integration_response.contact_form_cors_integration_response
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "contact_form_stage" {
  stage_name    = var.api_gateway_stage_name
  rest_api_id   = aws_api_gateway_rest_api.contact_form_api.id
  deployment_id = aws_api_gateway_deployment.contact_form_deployment.id

  tags = {
    Name        = "TravelContactAPIStage"
    Environment = var.environment
  }
}

# Inject API URL into script.js
resource "aws_s3_object" "script_js" {
  bucket = aws_s3_bucket.website_bucket.id
  key    = "script.js"

  content = templatefile("${path.module}/frontend/script.js.tpl", {
    api_gateway_url = "https://${aws_api_gateway_rest_api.contact_form_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.api_gateway_stage_name}"
  })

  content_type = "application/javascript"

}

# SES Email Identity verification
resource "aws_ses_email_identity" "email_identity" {
  email = var.ses_sender_email
}

# Output API Gateway Invoke URL
output "api_gateway_invoke_url" {
  value       = "${aws_api_gateway_stage.contact_form_stage.invoke_url}/submit"
  description = "The invoke URL for the API Gateway"
}