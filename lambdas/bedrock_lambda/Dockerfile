FROM public.ecr.aws/lambda/python:3.11

# 작업 디렉터리 설정
WORKDIR ${LAMBDA_TASK_ROOT}

# Bedrock Lambda 전용 의존성 설치
COPY lambdas/bedrock_lambda/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 소스 코드 복사
COPY lambdas/ ./lambdas/

# Lambda 핸들러 지정
CMD ["lambdas.bedrock_lambda.handler.lambda_handler"] 