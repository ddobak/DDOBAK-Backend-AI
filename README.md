# DDOBAK Lambda Backend AI

AWS Lambda 기반 AI 서비스를 위한 프로젝트입니다. Docker 컨테이너로 패키징되어 ECR을 통해 배포되며, Terraform으로 인프라를 관리합니다.

## 📁 프로젝트 구조

```
DDOBAK-Backend-AI/
├── lambdas/                    # Lambda 함수들
│   ├── ocr_lambda/            # OCR 처리 Lambda 함수
│   │   ├── handler.py         # Lambda 핸들러
│   │   ├── Dockerfile         # Docker 빌드 설정
│   │   └── __init__.py
│   ├── test_lambda/           # 테스트 Lambda 함수
│   │   ├── handler.py
│   │   ├── Dockerfile
│   │   └── __init__.py
│   └── __init__.py
├── scripts/
│   └── manager.sh             # 배포 관리 스크립트 (핵심 도구)
├── terraform/                 # Terraform 인프라 설정
│   ├── main.tf
│   ├── lambdas.tf
│   ├── iam.tf
│   └── modules/
├── tests/                     # 테스트 코드
├── lambda_config.yaml         # Lambda 통합 설정 파일 (중요!)
├── pyproject.toml             # Python 의존성 관리 (Poetry)
├── poetry.lock                # 의존성 잠금 파일
└── README.md                  # 프로젝트 문서
```

## ✨ 주요 특징

- **통합 설정 관리**: `lambda_config.yaml`로 모든 Lambda 설정을 중앙 관리
- **자동화된 배포**: `manager.sh` 스크립트로 빌드부터 배포까지 원클릭
- **기존 인프라 호환**: 기존 AWS 리소스와 충돌 없이 Terraform 관리 가능
- **Poetry 통합**: 의존성을 자동으로 `requirements.txt`로 변환하여 Docker 빌드

## 🚀 빠른 시작 가이드

### 1. 사전 요구사항

다음 도구들이 설치되어 있어야 합니다:

- **Python 3.11+**
- **Poetry** (Python 의존성 관리) - `curl -sSL https://install.python-poetry.org | python3 -`
- **Docker Desktop** (컨테이너 빌드용) - 실행 중이어야 함
- **AWS CLI** (AWS 리소스 관리) - `pip install awscli`
- **Terraform** (인프라 관리) - [공식 사이트](https://terraform.io) 참고

### 2. 저장소 클론 및 기본 설정

```bash
git clone <repository-url>
cd DDOBAK-Backend-AI

# AWS CLI 프로필 설정 (profile name: ddobak)
aws configure --profile ddobak
# 입력 필요: Access Key ID, Secret Key, Region (ap-northeast-2), Format (json)

# AWS 연결 확인
aws sts get-caller-identity --profile ddobak
```

### 3. 환경 초기화

```bash
# 프로젝트 초기화 (의존성 설치, Terraform 초기화)
./scripts/manager.sh init
```

### 4. 배포 시나리오별 가이드

#### 🆕 **시나리오 A: 완전히 새로운 환경 (처음 설정)**

```bash
# 1. 인프라 생성 계획 확인
./scripts/manager.sh terraform-plan

# 2. 인프라 생성
./scripts/manager.sh terraform-apply

# 3. Lambda 함수 배포
./scripts/manager.sh deploy all
```

#### 🔄 **시나리오 B: 기존 AWS 리소스가 있는 경우 (대부분의 경우)**

기존 ECR 리포지토리나 Lambda 함수가 있다면:

```bash
# 1. Terraform import로 기존 리소스 가져오기 (필요시)
# 스크립트가 자동으로 기존 리소스 감지하고 안내

# 2. 바로 코드 배포 (권장)
./scripts/manager.sh deploy all

# 또는 특정 함수만
./scripts/manager.sh deploy ocr_lambda
./scripts/manager.sh deploy test_lambda
```

#### 📦 **시나리오 C: 코드만 업데이트하고 싶은 경우**

```bash
# 인프라 변경 없이 코드만 업데이트
./scripts/manager.sh deploy all
```

## 📋 manager.sh 명령어 전체 가이드

### 🔧 **기본 명령어**

```bash
# 프로젝트 초기화 (최초 1회, 의존성 설치 + Terraform 초기화)
./scripts/manager.sh init

# 사용 가능한 Lambda 함수 목록 확인
./scripts/manager.sh list-lambdas

# 도움말 (전체 명령어 확인)
./scripts/manager.sh help
```

### 🏗️ **인프라 관리 (Terraform)**

```bash
# Terraform 실행 계획 확인 (실제 생성 전 미리보기)
./scripts/manager.sh terraform-plan

# AWS 인프라 생성/업데이트 (ECR, IAM 역할 등)
./scripts/manager.sh terraform-apply

# ⚠️ 모든 AWS 인프라 삭제 (주의!)
./scripts/manager.sh terraform-destroy
```

### 🚀 **Lambda 배포**

```bash
# 모든 Lambda 함수 배포 (가장 자주 사용)
./scripts/manager.sh deploy all

# 특정 Lambda 함수만 배포
./scripts/manager.sh deploy ocr_lambda
./scripts/manager.sh deploy test_lambda

# 💡 deploy 명령어가 수행하는 작업:
# 1. Poetry에서 requirements.txt 자동 생성
# 2. Docker 이미지 빌드 (linux/amd64)
# 3. ECR에 이미지 푸시
# 4. Lambda 함수 코드 업데이트
# 5. requirements.txt 자동 정리
```

### ⚙️ **고급 명령어**

```bash
# Lambda 설정 재생성 (새 Lambda 함수 추가 후)
./scripts/manager.sh re-init
```

### 🎯 **일반적인 사용 패턴**

```bash
# 코드 수정 후 재배포
./scripts/manager.sh deploy all

# 특정 함수만 수정했을 때
./scripts/manager.sh deploy ocr_lambda

# 새로운 Lambda 추가 후
./scripts/manager.sh re-init
./scripts/manager.sh terraform-apply  # 새 인프라 생성
./scripts/manager.sh deploy all       # 전체 배포
```

## 🔧 Lambda 설정 구조

### 📝 **통합 설정 파일 (`lambda_config.yaml`)**

모든 Lambda 함수의 설정이 한 곳에서 관리됩니다:

```yaml
lambdas:
  ocr_lambda:
    name: ocr_lambda
    function_name: ocr_lambda
    ecr_repository: ocr_lambda
    memory_size: 1024                # OCR은 메모리 많이 필요
    timeout: 30
    environment_variables:
      LOG_LEVEL: INFO
    cors_origins:
      - "*"
    description: "OCR Lambda function for text extraction"
  
  test_lambda:
    name: test_lambda
    function_name: test_lambda
    ecr_repository: test_lambda
    memory_size: 512                 # 테스트용은 적은 메모리
    timeout: 60
    environment_variables:
      LOG_LEVEL: INFO
    cors_origins:
      - "*"
    description: "Test Lambda function for development"
```

### 📂 **개별 Lambda 함수 구조**

각 `lambdas/{함수명}/` 디렉터리는 다음 구조를 가집니다:

```
lambdas/ocr_lambda/
├── handler.py         # Lambda 핸들러 (메인 로직)
├── Dockerfile         # Docker 빌드 설정
└── __init__.py       # Python 패키지 설정
```

#### `handler.py` 예시
```python
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """Lambda 함수 진입점"""
    try:
        # 비즈니스 로직 구현
        result = process_request(event)
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps(result)
        }
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def process_request(event):
    """실제 비즈니스 로직"""
    # 구현 내용
    pass

if __name__ == "__main__":
    # 로컬 테스트용 (Lambda에서는 실행되지 않음)
    test_event = {"test": "data"}
    result = lambda_handler(test_event, None)
    print(json.dumps(result, indent=2))
```

#### `Dockerfile` 핵심 포인트
```dockerfile
FROM public.ecr.aws/lambda/python:3.11

# 작업 디렉터리 설정
WORKDIR ${LAMBDA_TASK_ROOT}

# requirements.txt 복사 및 의존성 설치
# ⚠️ Poetry가 자동으로 생성하므로 수동 생성 불필요
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 소스 코드 복사
COPY lambdas/ ./lambdas/

# Lambda 핸들러 지정
CMD ["lambdas.ocr_lambda.handler.lambda_handler"]
```

## ➕ 새로운 Lambda 함수 추가하기

### 1️⃣ **디렉터리 및 파일 생성**

```bash
# 새 Lambda 함수 디렉터리 생성
mkdir lambdas/새함수명

# 기본 파일들 생성
touch lambdas/새함수명/__init__.py
touch lambdas/새함수명/handler.py

# 기존 Dockerfile 복사하여 수정
cp lambdas/ocr_lambda/Dockerfile lambdas/새함수명/
```

### 2️⃣ **handler.py 작성**

위의 handler.py 예시를 참고하여 비즈니스 로직 구현

### 3️⃣ **Dockerfile 수정**

```dockerfile
# 마지막 줄의 CMD 부분만 수정
CMD ["lambdas.새함수명.handler.lambda_handler"]
```

### 4️⃣ **통합 설정에 추가**

`lambda_config.yaml`에 새 함수 설정 추가:

```yaml
lambdas:
  # ... 기존 함수들 ...
  새함수명:
    name: 새함수명
    function_name: 새함수명
    ecr_repository: 새함수명
    memory_size: 512
    timeout: 30
    environment_variables:
      LOG_LEVEL: INFO
    cors_origins:
      - "*"
    description: "새로운 Lambda 함수 설명"
```

### 5️⃣ **인프라 업데이트 및 배포**

```bash
# Terraform으로 새 인프라 생성
./scripts/manager.sh terraform-apply

# 새 함수 배포
./scripts/manager.sh deploy 새함수명

# 또는 전체 배포
./scripts/manager.sh deploy all
```

## 🛠️ 개발 및 테스트

### 로컬 개발 환경 설정
```bash
# Poetry 쉘 활성화
poetry shell

# 의존성 설치
poetry install

# 개발 의존성 포함 설치
poetry install --with dev
```

### 라이브러리 관리 (Poetry 사용)

**모든 라이브러리 추가는 Poetry를 통해 관리하세요:**

```bash
# 새로운 라이브러리 추가
poetry add requests

# 개발용 라이브러리 추가
poetry add --group dev pytest-asyncio

# 특정 버전 지정
poetry add "fastapi>=0.100.0,<1.0.0"

# 라이브러리 제거
poetry remove requests

# 의존성 정보 확인
poetry show
poetry show --tree
```

### Lambda 함수 로컬 테스트

각 Lambda 함수는 `if __name__ == "__main__"` 블록을 통해 로컬에서 직접 테스트할 수 있습니다:

```bash
# OCR Lambda 함수 로컬 테스트
poetry run python lambdas/ocr_lambda/handler.py

# Test Lambda 함수 로컬 테스트  
poetry run python lambdas/test_lambda/handler.py
```

**로컬 테스트 블록 활용법:**
- `handler.py` 파일의 맨 아래 `if __name__ == "__main__":` 블록에 테스트 로직 추가
- 샘플 이벤트 데이터로 함수 동작 검증
- 디버깅용 로그 출력 
- 개발 중인 기능의 빠른 검증
- **Lambda 환경에서는 이 블록이 실행되지 않으므로 안전**


## 🚨 트러블슈팅 가이드

### ⚡ **자주 발생하는 문제와 해결법**

#### 1. **"Entity already exists" 오류 (Terraform)**
```bash
# 기존 AWS 리소스가 있을 때 발생
# 해결: import 명령어로 기존 리소스를 Terraform 상태로 가져오기

# ECR 리포지토리 import
terraform import 'module.lambdas["ocr_lambda"].aws_ecr_repository.lambda_repo' ocr_lambda

# IAM 역할 import  
terraform import aws_iam_role.lambda_execution_role ddobak-lambda-execution-role

# 또는 그냥 deploy 명령어 먼저 실행 (권장)
./scripts/manager.sh deploy all
```

#### 2. **"Source image does not exist" 오류**
```bash
# ECR에 이미지가 없을 때 발생
# 해결: deploy 먼저 실행 후 terraform-apply

./scripts/manager.sh deploy ocr_lambda  # 이미지 먼저 푸시
./scripts/manager.sh terraform-apply    # 그 다음 인프라 생성
```

#### 3. **"requirements.txt not found" 오류**
```bash
# Poetry 설정 문제
poetry install                          # 의존성 재설치
poetry export --format=requirements.txt --output=requirements.txt --without-hashes
```

#### 4. **AWS CLI 권한 문제**
```bash
# AWS 설정 확인
aws configure list --profile ddobak
aws sts get-caller-identity --profile ddobak

# 필요한 권한들:
# - ECR (이미지 푸시)
# - Lambda (함수 업데이트)
# - IAM (역할 관리)
```

#### 5. **Docker 빌드 실패**
```bash
# Docker 데몬 상태 확인
docker info

# Docker Desktop 재시작
# macOS: Docker Desktop 앱 재시작
# Linux: sudo systemctl restart docker
```

### 🔍 **로그 및 디버깅**

```bash
# CloudWatch 로그 확인
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/ --profile ddobak

# 특정 Lambda 함수 로그 스트림 확인
aws logs describe-log-streams --log-group-name /aws/lambda/ocr_lambda --profile ddobak

# 실시간 로그 확인 (배포 후 테스트할 때 유용)
aws logs tail /aws/lambda/ocr_lambda --follow --profile ddobak
```

### 💡 **성능 최적화 팁**

- **메모리 크기**: OCR 같은 무거운 작업은 1024MB+, 간단한 API는 512MB
- **타임아웃**: 보통 30-60초면 충분, 파일 처리는 더 길게
- **패키지 최적화**: 불필요한 의존성 제거 (`poetry remove unused_package`)
- **컨테이너 이미지**: 멀티스테이지 빌드로 이미지 크기 최적화

### 🔄 **완전 초기화가 필요한 경우**

```bash
# 1. 모든 AWS 리소스 삭제
./scripts/manager.sh terraform-destroy

# 2. Terraform 상태 초기화
cd terraform && rm -rf .terraform* terraform.tfstate*

# 3. 프로젝트 재초기화
./scripts/manager.sh init

# 4. 처음부터 다시 배포
./scripts/manager.sh terraform-apply
./scripts/manager.sh deploy all
```