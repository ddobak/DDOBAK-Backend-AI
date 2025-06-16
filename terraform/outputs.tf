# AWS 계정 및 리전 정보
output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}

# IAM 역할 정보
output "lambda_execution_role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.lambda_execution_role.arn
}

# 모든 Lambda 함수들의 정보 (모듈에서 출력)
output "lambda_functions" {
  description = "Information about all Lambda functions"
  value = {
    for name, lambda_module in module.lambdas : name => {
      function_name       = lambda_module.lambda_function_name
      function_arn        = lambda_module.lambda_function_arn
      function_url        = lambda_module.lambda_function_url
      ecr_repository_url  = lambda_module.ecr_repository_url
      ecr_repository_name = lambda_module.ecr_repository_name
      log_group_name      = lambda_module.cloudwatch_log_group_name
    }
  }
}

# 배포 정보 요약
output "deployment_info" {
  description = "Deployment information summary"
  value = {
    aws_account_id = data.aws_caller_identity.current.account_id
    aws_region     = data.aws_region.current.name
    lambda_functions = {
      for name, lambda_module in module.lambdas : name => {
        function_name      = lambda_module.lambda_function_name
        function_url       = lambda_module.lambda_function_url
        ecr_repository_url = lambda_module.ecr_repository_url
      }
    }
  }
} 