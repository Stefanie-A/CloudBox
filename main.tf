terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.8"
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

#Api gateway
resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "airbox-api"
  description = "This is the airbox API"
}

resource "aws_api_gateway_resource" "api_gateway_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "airbox"
}

resource "aws_api_gateway_method" "api_gateway_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.api_gateway_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_gateway_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.api_gateway_resource.id
  http_method             = aws_api_gateway_method.api_gateway_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "aws_lambda_function.lambda_function.invoke_arn"
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

resource "aws_iam_role" "lambda_role" {
  name               = var.lambda_role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_policy.json
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
  handler          = "app.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      foo = "bar"
    }
  }
}

#Dynamodb
resource "aws_dynamodb_table" "dynamodb_table" {
  name         = var.dynamodb_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "FileKey"
    type = "S"
  }

  attribute {
    name = "BukcetName"
    type = "S"
  }

  global_secondary_index {
    name            = "BucketNameIndex"
    hash_key        = "BucketName"
    projection_type = "ALL"
    read_capacity   = 1
    write_capacity  = 1
  }
}