variable "region" {
  description = "The AWS region"
  type        = string
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "lambda_role_name" {
  description = "The name of the Lambda role"
  type        = string
  default     = "airbox-role"
}

variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
  default     = "airbox-func"
}

variable "dynamodb_table" {
  description = "The name of the DynamoDB table"
  type        = string
  default     = "S3FileMetadata"
}