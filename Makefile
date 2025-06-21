.PHONY: init install format check test requirements build deploy deploy-ocr deploy-test clean help

# 환경 변수 설정
LAMBDA_NAME ?= ocr_lambda
AWS_PROFILE ?= ddobak
AWS_REGION ?= ap-northeast-2

# uv 설치 및 프로젝트 초기화
init:
	@echo "[INFO] uv 설치 및 프로젝트 초기화 중..."
	@if ! command -v uv &> /dev/null; then \
		echo "[INFO] uv 설치 중..."; \
		curl -LsSf https://astral.sh/uv/install.sh | sh; \
	fi
	@echo "[INFO] 가상환경 생성 및 의존성 설치 중..."
	uv venv
	. .venv/bin/activate
	uv sync
	@echo "[SUCCESS] 프로젝트 초기화 완료!"

# 의존성 설치 (개발 의존성 포함)
install:
	@echo "[INFO] 의존성 설치 중..."
	uv sync --group dev
	@echo "[SUCCESS] 의존성 설치 완료!"

# 의존성 설치 (운영 의존성만)
install-prod:
	@echo "[INFO] 운영 의존성만 설치 중..."
	uv sync --no-group dev
	@echo "[SUCCESS] 운영 의존성 설치 완료!"

# 코드 포맷팅
format:
	@echo "[INFO] 코드 포맷팅 중..."
	uv run black .
	@echo "[SUCCESS] 코드 포맷팅 완료!"

# 코드 검사 및 자동 수정
check:
	@echo "[INFO] 코드 검사 중..."
	uv run flake8 lambdas/ tests/
	uv run mypy lambdas/ --ignore-missing-imports
	@echo "[SUCCESS] 코드 검사 완료!"

# 테스트 실행
test:
	@echo "[INFO] 테스트 실행 중..."
	uv run pytest tests/ -v --cov=lambdas --cov-report=term-missing
	@echo "[SUCCESS] 테스트 완료!"

# 빠른 테스트 (커버리지 없이)
test-quick:
	@echo "[INFO] 빠른 테스트 실행 중..."
	uv run pytest tests/ -v
	@echo "[SUCCESS] 빠른 테스트 완료!"

# 특정 테스트 파일 실행
test-file:
	@echo "[INFO] 특정 테스트 파일 실행: $(FILE)"
	uv run pytest $(FILE) -v

# OCR Lambda 로컬 테스트
test-ocr:
	@echo "[INFO] OCR Lambda 로컬 테스트 실행 중..."
	uv run python lambdas/ocr_lambda/handler.py
	@echo "[SUCCESS] OCR Lambda 로컬 테스트 완료!"

# Test Lambda 로컬 테스트
test-lambda:
	@echo "[INFO] Test Lambda 로컬 테스트 실행 중..."
	uv run python lambdas/test_lambda/handler.py
	@echo "[SUCCESS] Test Lambda 로컬 테스트 완료!"

# requirements.txt 생성
requirements:
	@echo "[INFO] requirements.txt 생성 중..."
	uv export -o requirements.txt --no-hashes
	@echo "[SUCCESS] requirements.txt 생성 완료!"

# 의존성 추가
add:
	@if [ -z "$(PKG)" ]; then \
		echo "[ERROR] 패키지명을 지정해주세요. 예: make add PKG=requests"; \
		exit 1; \
	fi
	@echo "[INFO] 패키지 추가 중: $(PKG)"
	uv add $(PKG)
	@echo "[SUCCESS] 패키지 추가 완료: $(PKG)"

# 개발 의존성 추가
add-dev:
	@if [ -z "$(PKG)" ]; then \
		echo "[ERROR] 패키지명을 지정해주세요. 예: make add-dev PKG=pytest"; \
		exit 1; \
	fi
	@echo "[INFO] 개발 패키지 추가 중: $(PKG)"
	uv add --group dev $(PKG)
	@echo "[SUCCESS] 개발 패키지 추가 완료: $(PKG)"

# 의존성 제거
remove:
	@if [ -z "$(PKG)" ]; then \
		echo "[ERROR] 패키지명을 지정해주세요. 예: make remove PKG=requests"; \
		exit 1; \
	fi
	@echo "[INFO] 패키지 제거 중: $(PKG)"
	uv remove $(PKG)
	@echo "[SUCCESS] 패키지 제거 완료: $(PKG)"

# 의존성 트리 보기
tree:
	@echo "[INFO] 의존성 트리 표시 중..."
	uv tree

# 설치된 패키지 목록
list:
	@echo "[INFO] 설치된 패키지 목록:"
	uv pip list

# 전체 빌드 및 배포 (manager.sh 사용)
build:
	@echo "[INFO] 전체 빌드 및 배포 중..."
	./scripts/manager.sh deploy all

# OCR Lambda만 배포
deploy-ocr:
	@echo "[INFO] OCR Lambda 배포 중..."
	./scripts/manager.sh deploy ocr_lambda

# Test Lambda만 배포
deploy-test:
	@echo "[INFO] Test Lambda 배포 중..."
	./scripts/manager.sh deploy test_lambda

# 특정 Lambda 배포
deploy:
	@if [ -z "$(LAMBDA)" ]; then \
		echo "[ERROR] Lambda명을 지정해주세요. 예: make deploy LAMBDA=ocr_lambda"; \
		exit 1; \
	fi
	@echo "[INFO] $(LAMBDA) 배포 중..."
	./scripts/manager.sh deploy $(LAMBDA)

# Terraform 계획 확인
plan:
	@echo "[INFO] Terraform 계획 확인 중..."
	./scripts/manager.sh terraform-plan

# Terraform 적용
apply:
	@echo "[INFO] Terraform 적용 중..."
	./scripts/manager.sh terraform-apply

# Lambda 함수 목록
list-lambdas:
	@echo "[INFO] Lambda 함수 목록:"
	./scripts/manager.sh list-lambdas

# 개발 환경 설정 확인
doctor:
	@echo "[INFO] 개발 환경 확인 중..."
	@echo "Python 버전:"
	@uv run python --version || echo "Python 실행 실패"
	@echo "uv 버전:"
	@uv --version || echo "uv 실행 실패"
	@echo "AWS CLI:"
	@aws --version || echo "AWS CLI 실행 실패"
	@echo "Docker:"
	@docker --version || echo "Docker 실행 실패"
	@echo "Terraform:"
	@terraform --version || echo "Terraform 실행 실패"
	@echo "가상환경 상태:"
	@if [ -d ".venv" ]; then echo "✓ .venv 존재"; else echo "✗ .venv 없음"; fi
	@if [ -f "uv.lock" ]; then echo "✓ uv.lock 존재"; else echo "✗ uv.lock 없음"; fi

# 정리
clean:
	@echo "[INFO] 프로젝트 정리 중..."
	rm -rf .venv
	rm -rf __pycache__ */__pycache__ */*/__pycache__
	rm -rf .pytest_cache
	rm -rf .coverage
	rm -rf .mypy_cache
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info/
	rm -f requirements.txt
	@echo "[SUCCESS] 프로젝트 정리 완료!"

# 완전한 재설정
reset: clean
	@echo "[INFO] 프로젝트 완전 재설정 중..."
	rm -f uv.lock
	$(MAKE) init

# 도움말
help:
	@echo "DDOBAK Lambda AI 프로젝트 - uv 기반 Makefile"
	@echo ""
	@echo "초기 설정:"
	@echo "  make init          - uv 설치 및 프로젝트 초기화"
	@echo "  make install       - 의존성 설치 (개발 의존성 포함)"
	@echo "  make install-prod  - 운영 의존성만 설치"
	@echo ""
	@echo "개발 도구:"
	@echo "  make format        - 코드 포맷팅 (black)"
	@echo "  make check         - 코드 검사 (flake8, mypy)"
	@echo "  make test          - 전체 테스트 실행 (커버리지 포함)"
	@echo "  make test-quick    - 빠른 테스트 실행"
	@echo "  make test-file FILE=path/to/test.py - 특정 테스트 파일 실행"
	@echo ""
	@echo "Lambda 테스트:"
	@echo "  make test-ocr      - OCR Lambda 로컬 테스트"
	@echo "  make test-lambda   - Test Lambda 로컬 테스트"
	@echo ""
	@echo "의존성 관리:"
	@echo "  make add PKG=패키지명        - 패키지 추가"
	@echo "  make add-dev PKG=패키지명    - 개발 패키지 추가"
	@echo "  make remove PKG=패키지명     - 패키지 제거"
	@echo "  make tree                    - 의존성 트리 보기"
	@echo "  make list                    - 설치된 패키지 목록"
	@echo "  make requirements            - requirements.txt 생성"
	@echo ""
	@echo "배포:"
	@echo "  make build                   - 전체 빌드 및 배포"
	@echo "  make deploy-ocr              - OCR Lambda 배포"
	@echo "  make deploy-test             - Test Lambda 배포"
	@echo "  make deploy LAMBDA=이름      - 특정 Lambda 배포"
	@echo "  make plan                    - Terraform 계획 확인"
	@echo "  make apply                   - Terraform 적용"
	@echo "  make list-lambdas            - Lambda 함수 목록"
	@echo ""
	@echo "유틸리티:"
	@echo "  make doctor                  - 개발 환경 확인"
	@echo "  make clean                   - 프로젝트 정리"
	@echo "  make reset                   - 완전 재설정"
	@echo "  make help                    - 이 도움말 표시"
	@echo ""
	@echo "예시:"
	@echo "  make add PKG=requests        # requests 패키지 추가"
	@echo "  make add-dev PKG=pytest     # pytest 개발 패키지 추가"
	@echo "  make test-file FILE=tests/test_ocr_lambda.py  # 특정 테스트 파일 실행"
	@echo "  make deploy LAMBDA=ocr_lambda  # OCR Lambda 배포"
	@echo "  make test-ocr                # OCR Lambda 로컬 테스트" 