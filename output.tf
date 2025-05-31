# output "cognito_login_url" {
#   value       = "https://${aws_cognito_user_pool_domain.user_pool_domain.domain}.auth.${var.region}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.user_pool_client.id}&response_type=code&scope=email+openid&redirect_uri=http://localhost:5000/home"
#   description = "Cognito Hosted UI Login URL"
# }

# output "api_gateway_url" {
#   value       = aws_api_gateway_deployment.cloudbox_api.invoke_url
#   description = "The base URL for the CloudBox API Gateway"
# }
