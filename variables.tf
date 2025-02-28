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
  default     = "cloudbox-role"
}

variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
  default     = "cloudbox-func"
}

variable "dynamodb_table" {
  description = "The name of the DynamoDB table"
  type        = string
  default     = "S3FileMetadata"
}

variable "cognito_name" {
  description = "The name of the Cognito user pool"
  type        = string
  default     = "cloudbox-user-pool"

}

variable "cognito_client_name" {
  description = "The name of the Cognito user pool client"
  type        = string
  default     = "cloudbox-client"
}

variable "cognito_domain" {
  description = "The domain of the Cognito user pool"
  type        = string
  default     = "cloudbox"
}

variable "kinesis_stream_name" {
  description = "The name of the Kinesis stream"
  type        = string
  default     = "cloudbox-stream"

}

variable "identity_pool_name" {
  description = "The name of the Cognito identity pool"
  type        = string
  default     = "cloudbox-identity-pool"
}

variable "ecr_repository_name" {
  description = "The name of the ECR repository"
  type        = string
  default     = "cloudbox-repo"
  
}