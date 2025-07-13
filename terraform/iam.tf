# Lambda 실행 역할
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role"

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

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-lambda-execution-role"
  })
}

# Lambda 기본 실행 권한 (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda VPC 실행 권한 (필요시)
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# S3 접근 권한 (필요시 OCR용 이미지 다운로드)
resource "aws_iam_policy" "lambda_s3_access" {
  name        = "${var.project_name}-lambda-s3-access"
  description = "S3 access policy for Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

# S3 정책을 Lambda 역할에 연결
resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_s3_access.arn
}

# Bedrock 접근 권한 (Claude 모델 호출용)
resource "aws_iam_policy" "lambda_bedrock_access" {
  name        = "${var.project_name}-lambda-bedrock-access"
  description = "Bedrock access policy for Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

# Bedrock Agent Runtime 접근 권한 (Knowledge Base용)
resource "aws_iam_policy" "lambda_bedrock_agent_access" {
  name        = "${var.project_name}-lambda-bedrock-agent-access"
  description = "Bedrock Agent Runtime access policy for Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate"
        ]
        Resource = [
          "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:ListKnowledgeBases",
          "bedrock:GetKnowledgeBase"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

# Bedrock 정책을 Lambda 역할에 연결
resource "aws_iam_role_policy_attachment" "lambda_bedrock_access" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_bedrock_access.arn
}

# Bedrock Agent 정책을 Lambda 역할에 연결
resource "aws_iam_role_policy_attachment" "lambda_bedrock_agent_access" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_bedrock_agent_access.arn
}