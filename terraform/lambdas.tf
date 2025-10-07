# Lambda 통합 설정 로드
locals {
  # 통합 lambda_config.yaml 파일에서 Lambda 설정 로드
  lambda_config_file = yamldecode(file("${path.module}/../lambda_config.yaml"))
  
  # Lambda 설정을 Terraform에서 사용할 수 있도록 변환
  lambda_configs = local.lambda_config_file.lambdas
}

# 각 Lambda에 대해 모듈 생성
module "lambdas" {
  source = "./modules/lambda"
  
  for_each = local.lambda_configs
  
  # Lambda 기본 정보
  lambda_name           = each.key
  function_name         = each.value.function_name
  ecr_repository_name   = each.value.ecr_repository
  
  # 성능 설정
  memory_size = try(each.value.memory_size, 512)
  timeout     = try(each.value.timeout, 30)
  
  # 환경 변수
  environment_variables = try(each.value.environment_variables, {})
  
  
  # 공통 설정
  environment = var.environment
  project_name = var.project_name
  common_tags = local.common_tags
  
  # IAM 역할
  lambda_execution_role_arn = aws_iam_role.lambda_execution_role.arn
} 