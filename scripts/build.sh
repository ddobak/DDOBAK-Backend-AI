#!/bin/bash

# OCR Lambda Docker 이미지 빌드 스크립트

set -e

# 변수 설정
IMAGE_NAME="test-sample"
TAG=${1:-latest}
FULL_IMAGE_NAME="${IMAGE_NAME}:${TAG}"

echo "Building test-sample Docker image: ${FULL_IMAGE_NAME}"

# Docker 이미지 빌드
docker buildx build \
    --platform linux/amd64 \
    --provenance=false \
    -t "${FULL_IMAGE_NAME}" \
    .

echo "✅ Docker image built successfully: ${FULL_IMAGE_NAME}"

# 이미지 정보 출력
echo "📊 Image information:"
docker images | grep "${IMAGE_NAME}" | head -1 