# AWS Lambda Python 3.11 베이스 이미지 사용 (AMD64)
FROM --platform=linux/amd64 public.ecr.aws/lambda/python:3.11

# 작업 디렉토리 설정
WORKDIR ${LAMBDA_TASK_ROOT}

# 애플리케이션 코드 복사
COPY lambdas/ ${LAMBDA_TASK_ROOT}/lambdas/

# Lambda 핸들러 설정
CMD ["lambdas.ocr_lambda.handler.lambda_handler"] 