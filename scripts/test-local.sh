#!/bin/bash

# OCR Lambda 로컬 테스트 스크립트

set -e

IMAGE_NAME="ocr-lambda"
TAG=${1:-latest}
FULL_IMAGE_NAME="${IMAGE_NAME}:${TAG}"

echo "🧪 Testing OCR Lambda locally"

# 이미지가 존재하는지 확인
if ! docker image inspect ${FULL_IMAGE_NAME} >/dev/null 2>&1; then
    echo "❌ Docker image ${FULL_IMAGE_NAME} not found. Building it first..."
    ./scripts/build.sh ${TAG}
fi

# Lambda 런타임 인터페이스 에뮬레이터 설치 (필요한 경우)
RIE_DIR="$HOME/.aws-lambda-rie"
RIE_PATH="${RIE_DIR}/aws-lambda-rie"

if [ ! -f "${RIE_PATH}" ]; then
    echo "📥 Installing AWS Lambda Runtime Interface Emulator..."
    mkdir -p ${RIE_DIR}
    curl -Lo ${RIE_PATH} https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie
    chmod +x ${RIE_PATH}
fi

# 컨테이너 실행
echo "🚀 Starting Lambda container..."
CONTAINER_ID=$(docker run --platform linux/amd64 -d \
    -v ${RIE_DIR}:/aws-lambda \
    -p 9000:8080 \
    --entrypoint /aws-lambda/aws-lambda-rie \
    ${FULL_IMAGE_NAME} \
    /usr/local/bin/python -m awslambdaric lambdas.ocr_lambda.handler.lambda_handler)

echo "✅ Container started with ID: ${CONTAINER_ID}"
echo "📍 Lambda endpoint: http://localhost:9000/2015-03-31/functions/function/invocations"

# 잠시 대기 (컨테이너 시작 시간)
sleep 3

# 테스트 이벤트 전송
echo "📤 Sending test event..."
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
    -d '{
        "test": "sample event"
    }'

echo -e "\n"

# 컨테이너 정리
echo "🧹 Stopping and removing container..."
docker stop ${CONTAINER_ID}
docker rm ${CONTAINER_ID}

echo "✅ Local test completed" 