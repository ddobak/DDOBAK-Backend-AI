# DDOBAK Lambda Backend AI

AWS Lambda 기반 계약서 독소조항 추출 AI 서비스입니다. OCR을 통해 계약서 이미지에서 텍스트를 추출하고, Claude 3.5 Sonnet으로 독소조항을 분석합니다.

## 🚀 주요 기능

- **📄 OCR 처리**: Upstage API로 계약서 이미지에서 텍스트 추출
- **⚖️ 독소조항 분석**: Claude 3.5 Sonnet으로 불공정 조항 식별 및 위험도 평가
- **🔄 자동화 파이프라인**: 이미지 업로드 → OCR → 독소조항 분석
- **🐳 Docker 배포**: ECR + Terraform으로 AWS 인프라 관리
- **⚡ 간편한 개발**: Makefile로 모든 과정을 `make` 명령어 하나로 처리

## 📁 프로젝트 구조

```
DDOBAK-Backend-AI/
├── lambdas/
│   ├── ocr_lambda/         # 계약서 OCR 처리
│   ├── bedrock_lambda/     # 독소조항 분석 (Claude 3.5)
│   └── test_lambda/        # 개발 테스트용
├── scripts/manager.sh      # 배포 관리 스크립트
├── terraform/              # AWS 인프라 설정
├── lambda_config.yaml      # Lambda 통합 설정
└── README.md
```

## ⚡ 빠른 시작

### 1. 프로젝트 초기화 (Make 사용 권장)
```bash
make init

export UPSTAGE_API_KEY="your_api_key"
aws configure --profile ddobak
```

### 2. 배포
```bash
# 전체 빌드 및 배포
make build

# 개별 배포
make deploy-ocr
make deploy-bedrock

# 또는 scripts 직접 사용
./scripts/manager.sh deploy all
```

### 3. 로컬 테스트
```bash
# Makefile 사용 (권장)
make test-ocr
make test-bedrock

# 또는 직접 실행
uv run python lambdas/ocr_lambda/handler.py
uv run python lambdas/bedrock_lambda/handler.py
```

## 🔄 사용 흐름

```
계약서 이미지 → OCR Lambda → 텍스트 추출 → Bedrock Lambda → 독소조항 분석 결과
```

**분석 결과 예시:**
```json
{
  "status": "success",
  "model_used": "anthropic.claude-3-5-sonnet-20240620-v1:0",
  "data": {
    "originContent": "제1조 (목적) 본 계약은... (전체 계약서 원문)",
    "summary": "이 계약서는 서비스 이용 계약으로, 과도한 배상책임과 일방적 해지권 등 여러 독소조항이 발견되었습니다.",
    "ddobakCommentary": {
      "overallComment": "계약자에게 불리한 조항들이 다수 포함되어 재검토가 필요합니다.",
      "warningComment": "무제한 배상책임과 300% 위약금 조항이 특히 위험하며, 사전 통지 없는 일방적 해지권도 문제가 됩니다.",
      "advice": "해당 조항들의 수정을 요구하고, 불가능하다면 계약서 검토 후 신중히 결정하시기 바랍니다."
    },
    "toxicCount": 3,
    "toxics": [
      {
        "title": "무제한 배상책임 조항",
        "clause": "을은 서비스 이용 중 발생하는 모든 손해에 대해 갑에게 무제한 배상책임을 진다",
        "reason": "배상 한도가 없어 예상치 못한 거액의 손해배상 청구를 받을 위험이 있습니다",
        "warnLevel": "HIGH"
      }
    ]
  }
}
```
## 📋 API 사용법

### OCR Lambda
```bash
# S3 이벤트로 자동 트리거
# 이미지 업로드 → 자동 OCR 처리
```

### Bedrock Lambda
```bash
# API 호출
POST /bedrock_lambda
{
  "contract_text": "계약서 전문..."
}

# S3 이벤트 (텍스트 파일 업로드 시 자동 실행)
```

## 🎯 독소조항 분석 기능

### 📊 분석 결과 구성 요소
- **📄 originContent**: 계약서 원문 전체 보관
- **📝 summary**: 계약서 주요 내용 및 독소조항 요약
- **🤖 ddobakCommentary**: 또박이 AI의 전문적 코멘트
  - `overallComment`: 계약서 전체 평가
  - `warningComment`: 핵심 주의사항 요약  
  - `advice`: 계약자를 위한 실용적 조언
- **📊 toxicCount**: 발견된 독소조항 총 개수
- **⚠️ toxics**: 개별 독소조항 상세 분석
  - `title`: 조항의 핵심 문제점 (한눈에 파악 가능)
  - `clause`: 해당 조항 원문
  - `reason`: 문제가 되는 구체적 이유
  - `warnLevel`: 위험도 (HIGH/MEDIUM/LOW)

### 🔍 식별 가능한 독소조항 유형
- **과도한 책임 부담**: 무제한 배상책임, 과도한 위약금
- **불공정 계약 해지**: 일방적 해지권, 사전 통지 없는 해지  
- **개인정보 오남용**: 과도한 수집, 제3자 제공
- **불합리한 손해배상**: 과도한 배상액, 일방적 손해 전가

### 📱 모바일 앱 친화적 구조
위 JSON 구조는 모바일 앱에서 바로 활용할 수 있도록 설계되어, UI 컴포넌트와 1:1 매칭됩니다.

## 🚨 문제 해결

### 자주 발생하는 오류
```bash
# "Entity already exists" → 기존 AWS 리소스 존재
make build                       # 배포 먼저 실행

# "Source image does not exist" → ECR 이미지 없음  
make deploy-ocr                  # 이미지 먼저 푸시

# "requirements.txt not found"
make install                     # 의존성 재설치

# 개발 환경 문제 진단
make doctor                      # 환경 상태 종합 확인

# 완전 초기화가 필요한 경우
make reset                       # 프로젝트 완전 재설정
```

### IAM 권한 필요
- **OCR**: S3 GetObject
- **Bedrock**: Bedrock InvokeModel (Claude 3.5)
- **공통**: ECR, Lambda 관리 권한

---

📚 **더 자세한 정보**: 각 Lambda 함수의 상세한 구현 내용은 `lambdas/*/handler.py` 파일을 참고하세요.