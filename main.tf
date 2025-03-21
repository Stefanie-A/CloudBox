terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.8"
  backend "s3" {
    bucket         = "tf-state12345"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

#s3 bucket
resource "aws_s3_bucket" "s3_bucket" {
  bucket = var.s3_bucket_name
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_versioning" "s3_bucket_versioning" {
  bucket = aws_s3_bucket.s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }

}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_bucket_encryption" {
  bucket = aws_s3_bucket.s3_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

}

resource "aws_s3_bucket_public_access_block" "s3_bucket_public_access_block" {
  bucket                  = aws_s3_bucket.s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.s3_bucket.id
  policy = data.aws_iam_policy_document.iam-policy.json
}

data "aws_iam_policy_document" "iam-policy" {
  statement {
    sid     = "AllowOAIRead"
    effect  = "Allow"
    actions = ["S3:GetObject"]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.s3_bucket.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.s3_bucket.bucket}/*",
    ]
    principals {
      type        = "CanonicalUser"
      identifiers = [aws_cloudfront_origin_access_identity.oai.s3_canonical_user_id]
    }
  }
}

# IAM Policy Document for Firehose Assume Role
data "aws_iam_policy_document" "firehose_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}


# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_policy.json
}


# IAM Role for Firehose
resource "aws_iam_role" "firehose_role" {
  name               = "firehose_role"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role.json
}

# IAM Policy for Firehose to Write to S3
data "aws_iam_policy_document" "firehose_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "firehose:PutRecord",
      "firehose:PutRecordBatch",
      "firehose:DescribeDeliveryStream",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:s3:::${var.s3_bucket_name}/*",
      "arn:aws:firehose:us-east-1:${data.aws_caller_identity.current.account_id}:deliverystream/${var.firehose_stream_name}"
    ]
  }
}

resource "aws_iam_policy" "firehose_policy" {
  name        = "firehose_policy"
  description = "Allows Firehose to put objects in S3 and Lambda"
  policy      = data.aws_iam_policy_document.firehose_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "firehose_s3_attach" {
  policy_arn = aws_iam_policy.firehose_policy.arn
  role       = aws_iam_role.firehose_role.name
}

resource "aws_iam_role_policy_attachment" "lambda_firehose_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}

data "aws_caller_identity" "current" {}



resource "aws_s3_bucket_website_configuration" "bucket" {
  bucket = aws_s3_bucket.s3_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

#Api gateway
resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "cloudbox-api"
  description = "This is the airbox API"
}
#/upload route
resource "aws_api_gateway_resource" "api_gateway_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "upload"
}

resource "aws_api_gateway_method" "api_gateway_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.api_gateway_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_integration" "api_gateway_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.api_gateway_resource.id
  http_method             = aws_api_gateway_method.api_gateway_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

#/fetch route
resource "aws_api_gateway_resource" "fetch" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "fetch"
}

resource "aws_api_gateway_method" "fetch_get" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.fetch.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_integration" "fetch_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.fetch.id
  http_method             = aws_api_gateway_method.fetch_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_api_gateway_method_response" "api_gateway_method_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.api_gateway_resource.id
  http_method = aws_api_gateway_method.api_gateway_method.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}


#lambda function
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*"
}


data "archive_file" "lambda_zip" {
  excludes = [
    ".terraform/*",
    ".git/*",
    ".gitignore",
    "terraform.tfstate",
    "terraform.tfstate.backup",
    "app/.terraform/*",
    "app/.git/*",
    "app/.gitignore",
    "*.tf",
    "*.tfvars",
    "*.tfstate",
    "*.tfstate.backup",
    "app/terraform.tfstate",
    "app/terraform.tfstate.backup",
  ]
  type        = "zip"
  source_dir  = "${path.module}/./app"
  output_path = "${path.module}/deployment-package.zip"
}
resource "aws_lambda_function" "lambda_function" {
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      foo            = "bar"
      S3_BUCKET      = aws_s3_bucket.s3_bucket.bucket
      DYNAMODB_TABLE = aws_dynamodb_table.dynamodb_table.name
    }
  }
  depends_on = [aws_iam_role.lambda_role]
}

#Dynamodb
resource "aws_dynamodb_table" "dynamodb_table" {
  name         = "S3FileMetadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "file_id"
  range_key    = "user_id"

  attribute {
    name = "file_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  # Define GSI attributes
  attribute {
    name = "Timestamp"
    type = "S"
  }

  attribute {
    name = "file_name"
    type = "S"
  }

  attribute {
    name = "file_key"
    type = "S"
  }

  attribute {
    name = "presigned_url"
    type = "S"
  }

  # Define GSI for querying files by timestamp
  global_secondary_index {
    name            = "TimestampIndex"
    hash_key        = "Timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "FileNameIndex"
    hash_key        = "file_name"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "FileKeyIndex"
    hash_key        = "file_key"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "PresignedurlIndex"
    hash_key        = "presigned_url"
    projection_type = "ALL"
  }
}



#cloudfront
resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  origin {
    domain_name = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id       = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
    viewer_protocol_policy = "allow-all"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "Allow CloudFront to reach the bucket"
}

#cognito
resource "aws_cognito_user_pool" "user_pool" {
  name = var.cognito_name
  # alias_attributes         = ["email"]
  auto_verified_attributes = ["email"]
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name                                 = var.cognito_client_name
  user_pool_id                         = aws_cognito_user_pool.user_pool.id
  generate_secret                      = false
  explicit_auth_flows                  = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]
  prevent_user_existence_errors        = "ENABLED"
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  supported_identity_providers         = ["COGNITO"]
}

resource "aws_cognito_user_pool_domain" "user_pool_domain" {
  domain       = var.cognito_domain
  user_pool_id = aws_cognito_user_pool.user_pool.id
}


# resource "aws_cognito_user_pool_ui_customization" "user_pool_ui_customization" {
#   css          = ".label-customizable {font-weight: 400;}"
#   image_file   = filebase64("${path.module}/logo.png")
#   user_pool_id = aws_cognito_user_pool_domain.user_pool_domain.user_pool_id
# }

resource "aws_cognito_identity_pool" "identity_pool" {
  identity_pool_name               = var.identity_pool_name
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id     = aws_cognito_user_pool_client.user_pool_client.id
    provider_name = aws_cognito_user_pool.user_pool.endpoint
  }
}

#kinesis firehose
resource "aws_kinesis_firehose_delivery_stream" "s3_stream" {
  name        = var.kinesis_stream_name
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.s3_bucket.arn

    processing_configuration {
      enabled = "true"

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.lambda_function.arn
        }
      }
    }
  }
}

#ECR
resource "aws_ecr_repository" "ecr_repository" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_iam_policy" "dynamodb_write_policy" {
  name        = "dynamodb_write_policy"
  description = "Allow Lambda to write to DynamoDB"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem"
        ],
        Resource = "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/S3FileMetadata"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.dynamodb_write_policy.arn
}


#API Gateway Cognito Authorizer
resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name            = "cognito-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.api_gateway.id
  type            = "COGNITO_USER_POOLS"
  identity_source = "method.request.header.Authorization"
  provider_arns   = [aws_cognito_user_pool.user_pool.arn]
}
