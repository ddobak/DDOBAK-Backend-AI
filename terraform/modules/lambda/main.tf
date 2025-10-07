# ECR 리포지토리
resource "aws_ecr_repository" "lambda_repo" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  # 이미지 스캔 설정
  image_scanning_configuration {
    scan_on_push = true
  }

  # 암호화 설정
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.lambda_name}-ecr-repository"
  })

  # 이미 존재하는 리소스는 무시
  lifecycle {
    ignore_changes = [name]
  }
}

# ECR 리포지토리 수명주기 정책
resource "aws_ecr_lifecycle_policy" "lambda_repo_policy" {
  repository = aws_ecr_repository.lambda_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# CloudWatch Logs 그룹
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14

  tags = merge(var.common_tags, {
    Name = "${var.function_name}-logs"
  })
}

# Lambda 함수
resource "aws_lambda_function" "lambda_function" {
  function_name = var.function_name
  role          = var.lambda_execution_role_arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lambda_repo.repository_url}:latest"
  
  timeout     = var.timeout
  memory_size = var.memory_size

  # 환경 변수
  environment {
    variables = merge({
      ENVIRONMENT = var.environment
    }, var.environment_variables)
  }

  # CloudWatch Logs 의존성
  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
  ]

  tags = merge(var.common_tags, {
    Name = var.function_name
  })

  # 이미지가 없을 때를 위한 lifecycle 설정
  lifecycle {
    ignore_changes = [image_uri]
  }
}

