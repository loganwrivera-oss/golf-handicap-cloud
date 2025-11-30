terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- 1. DATABASE (DynamoDB) ---
resource "aws_dynamodb_table" "golf_scores" {
  name           = "golf-handicap-scores"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "UserId"
  range_key      = "DatePlayed"

  attribute {
    name = "UserId"
    type = "S"
  }

  attribute {
    name = "DatePlayed"
    type = "S"
  }

  tags = {
    Project = "GolfHandicap"
  }
}

# --- 2. FRONTEND HOSTING (S3) ---
resource "aws_s3_bucket" "frontend_bucket" {
  # !!! IMPORTANT: PUT YOUR UNIQUE BUCKET NAME HERE !!!
  bucket = "golf-app-texas-logan" 
  
  force_destroy = true 
}

resource "aws_s3_bucket_website_configuration" "golf_hosting" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id
  depends_on = [aws_s3_bucket_public_access_block.public_access]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      },
    ]
  })
}

# --- 3. BACKEND (Lambda Setup) ---

# Zip the Python code automatically
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "../backend/lambda_function.py"
  output_path = "lambda_function.zip"
}

# IAM Role (The "Identity" for the function)
resource "aws_iam_role" "iam_for_lambda" {
  name = "golf_handicap_lambda_role"

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
}

# Attach Basic Permissions (Logging)
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# The Lambda Function Itself
resource "aws_lambda_function" "handicap_calculator" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "calculate_handicap"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# --- 4. API GATEWAY ---

resource "aws_apigatewayv2_api" "golf_api" {
  name          = "golf-handicap-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.golf_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.golf_api.id
  integration_type = "AWS_PROXY"

  integration_uri    = aws_lambda_function.handicap_calculator.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "calculate_route" {
  api_id    = aws_apigatewayv2_api.golf_api.id
  route_key = "POST /calculate"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.handicap_calculator.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.golf_api.execution_arn}/*/*/calculate"
}

# --- 5. OUTPUTS ---
output "api_endpoint" {
  value = "${aws_apigatewayv2_api.golf_api.api_endpoint}/calculate"
}

output "website_url" {
  value = aws_s3_bucket_website_configuration.golf_hosting.website_endpoint
}