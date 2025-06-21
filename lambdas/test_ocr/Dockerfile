# AWS Lambda Python 3.11 베이스 이미지 사용
# M1 맥북 사용자: 로컬 개발 시 --platform=linux/amd64 옵션 제거하고 빌드하면 더 빠름
FROM public.ecr.aws/lambda/python:3.11

# 작업 디렉터리 설정
WORKDIR ${LAMBDA_TASK_ROOT}

# requirements.txt 파일 복사 및 의존성 설치
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 애플리케이션 코드 복사
COPY lambdas/ ${LAMBDA_TASK_ROOT}/lambdas/

# Lambda 핸들러 설정
CMD ["lambdas.test_ocr.handler.lambda_handler"] 