# Terraform Infrastructure for DDOBAK OCR Lambda

이 Terraform 구성은 DDOBAK OCR Lambda 함수를 위한 AWS 인프라를 생성합니다.

## 🏗️ 생성되는 리소스

### ECR (Elastic Container Registry)
- **ECR 리포지토리**: Docker 이미지 저장
- **수명주기 정책**: 오래된 이미지 자동 정리
- **이미지 스캔**: 보안 취약점 자동 스캔

### Lambda 함수
- **Lambda 함수**: 컨테이너 기반 서버리스 함수
- **Function URL**: HTTP(S) 엔드포인트로 직접 호출 가능
- **CORS 설정**: 웹 브라우저에서 직접 호출 가능

### IAM 권한
- **Lambda 실행 역할**: 필요한 최소 권한
- **CloudWatch Logs 권한**: 로그 기록
- **S3 접근 권한**: 이미지 파일 읽기 (옵션)

### CloudWatch
- **로그 그룹**: Lambda 함수 실행 로그
- **자동 로그 보존**: 14일간 보관

## 🚀 사용법

### 1. 환경 설정

```bash
# Terraform 디렉토리로 이동
cd terraform

# 변수 파일 복사 및 수정
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 파일을 필요에 따라 수정
```

### 2. Terraform 초기화

```bash
terraform init
```

### 3. 계획 확인

```bash
terraform plan
```

### 4. 인프라 배포

```bash
terraform apply
```

### 5. 출력 정보 확인

```bash
terraform output
```

## 📋 주요 출력 정보

- **ecr_repository_url**: ECR 리포지토리 URL
- **lambda_function_url**: Lambda Function URL (HTTP 엔드포인트)
- **lambda_function_name**: Lambda 함수 이름
- **aws_account_id**: AWS 계정 ID

## 🔧 설정 사용자화

### terraform.tfvars 파일

```hcl
# AWS 설정
aws_profile = "your-profile"
aws_region  = "ap-northeast-2"

# 프로젝트 설정
project_name = "your-project"
environment  = "dev"

# Lambda 설정
lambda_function_name = "your-lambda-function"
lambda_memory_size   = 1024
lambda_timeout       = 30

# CORS 설정
lambda_cors_allow_origins = ["https://yourdomain.com"]
```

## 🌐 Lambda Function URL 사용법

배포 완료 후 출력되는 Function URL을 사용하여 Lambda 함수를 직접 호출할 수 있습니다:

```bash
# GET 요청
curl https://your-function-url.lambda-url.ap-northeast-2.on.aws/

# POST 요청
curl -X POST https://your-function-url.lambda-url.ap-northeast-2.on.aws/ \
  -H "Content-Type: application/json" \
  -d '{"test": "sample event"}'
```

## 🧹 정리

인프라를 삭제하려면:

```bash
terraform destroy
```

## 📦 Docker 이미지 배포

인프라 생성 후 Docker 이미지를 배포하려면:

```bash
# 프로젝트 루트로 이동
cd ..

# ECR에 로그인 (Terraform 출력에서 확인한 정보 사용)
aws ecr get-login-password --region ap-northeast-2 --profile ddobak | \
docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 빌드
docker buildx build --platform linux/amd64 --provenance=false -t ocr-lambda:latest .

# 이미지 태깅
docker tag ocr-lambda:latest <ECR_REPOSITORY_URL>:latest

# 이미지 푸시
docker push <ECR_REPOSITORY_URL>:latest

# Lambda 함수 업데이트
aws lambda update-function-code \
  --function-name ddobak-ocr-function \
  --image-uri <ECR_REPOSITORY_URL>:latest \
  --region ap-northeast-2 \
  --profile ddobak
```

## 🔒 보안 고려사항

1. **Function URL 인증**: 현재 인증 없이 공개 접근으로 설정됨
2. **CORS 설정**: 필요에 따라 허용 오리진을 제한
3. **IAM 권한**: 최소 권한 원칙 적용
4. **VPC**: 필요시 Lambda를 VPC 내부에 배치 가능

## 🏷️ 태그 관리

모든 리소스에는 다음 태그가 자동으로 적용됩니다:
- `Project`: 프로젝트 이름
- `Environment`: 환경 (dev/staging/prod)
- `ManagedBy`: terraform 