# DDOBAK Lambda Backend AI

AWS Lambda 기반 계약서 독소조항 추출 AI 서비스입니다. OCR을 통해 계약서 이미지에서 텍스트를 추출하고, Claude 3.5 Sonnet으로 독소조항을 분석합니다.

## 주요 기능

- **OCR 처리**: Upstage API로 계약서 이미지에서 텍스트 추출
- **독소조항 분석**: Claude 3.5 Sonnet으로 불공정 조항 식별 및 위험도 평가
- **자동화 파이프라인**: 이미지 업로드 → OCR → 독소조항 분석
- **Docker 배포**: ECR + Terraform으로 AWS 인프라 관리
