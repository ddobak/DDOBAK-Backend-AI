#!/bin/bash

# Lambda 배포 관리 스크립트 (Terraform 기반)
# 사용법: ./scripts/manager.sh [init|list-lambdas|deploy|terraform-plan|terraform-apply|re-init]

set -e

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수들
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 프로젝트 루트 디렉터리 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LAMBDAS_DIR="$PROJECT_ROOT/lambdas"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# AWS 설정
AWS_PROFILE="ddobak"
AWS_REGION="ap-northeast-2"

# 필수 도구 확인
check_requirements() {
    local tools=("aws" "docker" "terraform" "uv")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "다음 도구들이 설치되어 있지 않습니다: ${missing_tools[*]}"
        log_error "필요한 도구들을 설치 후 다시 시도해주세요."
        exit 1
    fi
    
    # AWS CLI 설정 확인
    if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &> /dev/null; then
        log_error "AWS CLI 프로필 '$AWS_PROFILE'가 설정되지 않았습니다."
        log_error "'aws configure --profile $AWS_PROFILE'를 실행해주세요."
        exit 1
    fi
    
    # Docker 실행 확인
    if ! docker info &> /dev/null; then
        log_error "Docker가 실행되지 않았습니다. Docker Desktop을 시작해주세요."
        exit 1
    fi
}

# Terraform 상태 확인
check_terraform_state() {
    cd "$TERRAFORM_DIR"
    
    if [ ! -f ".terraform.lock.hcl" ]; then
        log_warning "Terraform이 초기화되지 않았습니다. 'terraform init'을 실행합니다."
        terraform init
    fi
    
    # Terraform 계획 확인
    if ! terraform plan -detailed-exitcode &> /dev/null; then
        local plan_status=$?
        if [ $plan_status -eq 2 ]; then
            log_warning "Terraform 인프라에 변경사항이 있습니다."
            log_warning "먼저 'terraform apply'를 실행하여 인프라를 업데이트해주세요."
            return 1
        fi
    fi
    
    return 0
}

# Terraform 출력값 가져오기
get_terraform_output() {
    local output_name="$1"
    cd "$TERRAFORM_DIR"
    terraform output -raw "$output_name" 2>/dev/null || echo ""
}

# Lambda 함수 목록 가져오기
get_lambda_functions() {
    # 통합 lambda_config.yaml 파일에서 Lambda 목록 가져오기
    python3 -c "
import yaml
import os
config_file = os.path.join('$PROJECT_ROOT', 'lambda_config.yaml')
if os.path.exists(config_file):
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f)
    for lambda_name in config.get('lambdas', {}):
        print(lambda_name)
"
}

# ECR 로그인
ecr_login() {
    local account_id=$(get_terraform_output "aws_account_id")
    local region=$(get_terraform_output "aws_region")
    
    if [ -z "$account_id" ] || [ -z "$region" ]; then
        log_error "Terraform 출력에서 AWS 정보를 가져올 수 없습니다."
        log_error "먼저 'terraform apply'를 실행해주세요."
        exit 1
    fi
    
    local ecr_uri="${account_id}.dkr.ecr.${region}.amazonaws.com"
    
    log_info "ECR에 로그인 중... (${ecr_uri})"
    aws ecr get-login-password --region "$region" --profile "$AWS_PROFILE" | \
        docker login --username AWS --password-stdin "$ecr_uri"
    log_success "ECR 로그인 완료"
}

# Docker 이미지 빌드 및 푸시
build_and_push_image() {
    local lambda_name="$1"
    local lambda_dir="$LAMBDAS_DIR/$lambda_name"
    
    if [ ! -d "$lambda_dir" ]; then
        log_error "Lambda 디렉터리를 찾을 수 없습니다: $lambda_dir"
        return 1
    fi
    
    if [ ! -f "$lambda_dir/Dockerfile" ]; then
        log_error "Dockerfile을 찾을 수 없습니다: $lambda_dir/Dockerfile"
        return 1
    fi
    
    # Terraform 출력에서 ECR 정보 가져오기
    local account_id=$(get_terraform_output "aws_account_id")
    local region=$(get_terraform_output "aws_region")
    
    # 통합 설정에서 ECR 리포지토리명 가져오기
    local ecr_repository=$(python3 -c "
import yaml
import os
config_file = os.path.join('$PROJECT_ROOT', 'lambda_config.yaml')
with open(config_file, 'r') as f:
    config = yaml.safe_load(f)
print(config['lambdas']['$lambda_name']['ecr_repository'])
")
    
    local ecr_uri="${account_id}.dkr.ecr.${region}.amazonaws.com"
    local image_tag="${ecr_uri}/${ecr_repository}:latest"
    
    # uv에서 requirements.txt 생성
    log_info "requirements.txt 파일 생성 중..."
    cd "$PROJECT_ROOT"
    uv export -o requirements.txt --no-hashes --no-editable
    # '.' 항목 제거 (editable install 방지)
    sed -i '' '/^\.$/d' requirements.txt
    
    # 빌드 성공/실패 여부에 관계없이 requirements.txt 정리하도록 trap 설정
    trap 'rm -f "$PROJECT_ROOT/requirements.txt"' EXIT
    
    log_info "Docker 이미지 빌드 중: $lambda_name"
    # Legacy Docker builder 사용 (Lambda 호환성을 위해 단일 플랫폼 이미지 생성)
    export DOCKER_BUILDKIT=0
    if docker build --platform linux/amd64 -t "$image_tag" -f "$lambda_dir/Dockerfile" "$PROJECT_ROOT"; then
        log_info "Docker 이미지 푸시 중: $ecr_repository"
        docker push "$image_tag"
        log_success "Docker 이미지 빌드 및 푸시 완료: $lambda_name"
    else
        log_error "Docker 이미지 빌드 실패: $lambda_name"
        return 1
    fi
    
    # requirements.txt 정리
    rm -f "$PROJECT_ROOT/requirements.txt"
    trap - EXIT
}

# Lambda 함수 코드 업데이트
update_lambda_function() {
    local lambda_name="$1"
    
    # 통합 설정에서 함수명 가져오기
    local function_name=$(python3 -c "
import yaml
import os
config_file = os.path.join('$PROJECT_ROOT', 'lambda_config.yaml')
with open(config_file, 'r') as f:
    config = yaml.safe_load(f)
print(config['lambdas']['$lambda_name']['function_name'])
")
    
    # Terraform 출력에서 AWS 정보 가져오기
    local account_id=$(get_terraform_output "aws_account_id")
    local region=$(get_terraform_output "aws_region")
    
    # 통합 설정에서 ECR 리포지토리명 가져오기
    local ecr_repository=$(python3 -c "
import yaml
import os
config_file = os.path.join('$PROJECT_ROOT', 'lambda_config.yaml')
with open(config_file, 'r') as f:
    config = yaml.safe_load(f)
print(config['lambdas']['$lambda_name']['ecr_repository'])
")
    
    local image_uri="${account_id}.dkr.ecr.${region}.amazonaws.com/${ecr_repository}:latest"
    
    log_info "Lambda 함수 '$function_name' 코드 업데이트 중..."
    aws lambda update-function-code \
        --function-name "$function_name" \
        --image-uri "$image_uri" \
        --region "$region" \
        --profile "$AWS_PROFILE" > /dev/null
    
    log_success "Lambda 함수 '$function_name' 코드 업데이트 완료"
}

# 프로젝트 초기화
init_project() {
    log_info "프로젝트 초기화 중..."
    
    # 의존성 확인
    check_requirements
    
    # uv 의존성 설치
    log_info "uv 의존성 설치 중..."
    cd "$PROJECT_ROOT"
    uv sync
    
    # Terraform 초기화
    log_info "Terraform 초기화 중..."
    cd "$TERRAFORM_DIR"
    terraform init
    
    log_success "프로젝트 초기화 완료"
    log_info ""
    log_info "다음 단계:"
    log_info "1. terraform.tfvars 파일을 확인하고 필요시 수정"
    log_info "2. './scripts/manager.sh terraform-apply'로 인프라 생성"
    log_info "3. './scripts/manager.sh deploy <lambda_name>'으로 Lambda 배포"
}

# Lambda 함수 목록 출력
list_lambdas() {
    log_info "사용 가능한 Lambda 함수들:"
    
    local lambdas
    if ! lambdas=($(get_lambda_functions)); then
        return 1
    fi
    
    if [ ${#lambdas[@]} -eq 0 ]; then
        log_warning "배포 가능한 Lambda 함수가 없습니다."
        return
    fi
    
    for lambda_name in "${lambdas[@]}"; do
        local description=$(python3 -c "
import yaml
import os
try:
    config_file = os.path.join('$PROJECT_ROOT', 'lambda_config.yaml')
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f)
    print(config['lambdas']['$lambda_name'].get('description', 'Lambda function'))
except:
    print('Lambda function')
")
        echo -e "  ${GREEN}${lambda_name}${NC} - ${description}"
    done
}

# Terraform 계획 확인
terraform_plan() {
    log_info "Terraform 계획을 확인합니다..."
    check_requirements
    cd "$TERRAFORM_DIR"
    terraform plan
}

# Terraform 적용
terraform_apply() {
    log_info "Terraform을 적용합니다..."
    check_requirements
    cd "$TERRAFORM_DIR"
    terraform apply
    log_success "Terraform 적용 완료"
}

# Terraform 삭제
terraform_destroy() {
    log_warning "⚠️ 주의: 모든 AWS 리소스가 삭제됩니다!"
    read -p "계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        check_requirements
        cd "$TERRAFORM_DIR"
        terraform destroy
        log_success "Terraform 리소스 삭제 완료"
    else
        log_info "취소되었습니다."
    fi
}

# 특정 Lambda 함수 배포
deploy_single() {
    local lambda_name="$1"
    
    log_info "Lambda 함수 '$lambda_name' 배포 시작..."
    
    # 의존성 확인
    check_requirements
    
    # Terraform 상태 확인
    if ! check_terraform_state; then
        log_error "먼저 './scripts/manager.sh terraform-apply'를 실행하여 인프라를 생성해주세요."
        exit 1
    fi
    
    # Lambda 함수 존재 확인
    local lambdas=($(get_lambda_functions))
    if [[ ! " ${lambdas[@]} " =~ " $lambda_name " ]]; then
        log_error "Lambda 함수 '$lambda_name'을 찾을 수 없습니다."
        log_info "사용 가능한 Lambda 함수들:"
        list_lambdas
        exit 1
    fi
    
    # ECR 로그인
    ecr_login
    
    # Docker 이미지 빌드 및 푸시
    build_and_push_image "$lambda_name"
    
    # Lambda 함수 코드 업데이트
    update_lambda_function "$lambda_name"
    
    log_success "Lambda 함수 '$lambda_name' 배포 완료!"
}

# 모든 Lambda 함수 배포
deploy_all() {
    log_info "모든 Lambda 함수 배포 시작..."
    
    # 의존성 확인
    check_requirements
    
    # Terraform 상태 확인
    if ! check_terraform_state; then
        log_error "먼저 './scripts/manager.sh terraform-apply'를 실행하여 인프라를 생성해주세요."
        exit 1
    fi
    
    # Lambda 함수 목록 가져오기
    local lambdas=($(get_lambda_functions))
    
    if [ ${#lambdas[@]} -eq 0 ]; then
        log_warning "배포 가능한 Lambda 함수가 없습니다."
        return
    fi
    
    # ECR 로그인
    ecr_login
    
    local success_count=0
    local total_count=${#lambdas[@]}
    
    for lambda_name in "${lambdas[@]}"; do
        log_info "처리 중: $lambda_name ($((success_count + 1))/${total_count})"
        
        if build_and_push_image "$lambda_name" && update_lambda_function "$lambda_name"; then
            ((success_count++))
            log_success "✓ $lambda_name 배포 완료"
        else
            log_error "✗ $lambda_name 배포 실패"
        fi
        
        echo "----------------------------------------"
    done
    
    log_success "배포 완료: ${success_count}/${total_count} 성공"
}

# 설정 재생성
re_init() {
    log_info "통합 설정 파일 재생성 중..."
    
    # 기존 개별 lambda.yaml 파일들을 제거
    find "$LAMBDAS_DIR" -name "lambda.yaml" -type f -delete
    
    # Lambda 디렉토리들을 찾아서 통합 설정 파일 업데이트
    local lambda_dirs=($(find "$LAMBDAS_DIR" -type d -maxdepth 1 -mindepth 1))
    
    if [ ${#lambda_dirs[@]} -eq 0 ]; then
        log_warning "Lambda 디렉토리가 없습니다."
        return
    fi
    
    # 통합 설정 파일이 없으면 생성
    local config_file="$PROJECT_ROOT/lambda_config.yaml"
    if [ ! -f "$config_file" ]; then
        echo "lambdas:" > "$config_file"
        
        for lambda_dir in "${lambda_dirs[@]}"; do
            local lambda_name=$(basename "$lambda_dir")
            if [ "$lambda_name" != "__pycache__" ]; then
                cat >> "$config_file" << EOF
  $lambda_name:
    name: $lambda_name
    function_name: $lambda_name
    ecr_repository: $lambda_name
    memory_size: 512
    timeout: 30
    environment_variables:
      LOG_LEVEL: INFO
    cors_origins:
      - "*"
    description: "Lambda function: $lambda_name"
EOF
                log_success "✓ $lambda_name 설정을 통합 파일에 추가"
            fi
        done
    else
        log_info "✓ 통합 설정 파일이 이미 존재합니다: $config_file"
    fi
    
    log_success "통합 설정 파일 재생성 완료"
}

# 도움말 출력
show_help() {
    echo "Lambda 배포 관리 스크립트 (Terraform 기반)"
    echo ""
    echo "사용법:"
    echo "  ./scripts/manager.sh init                  - 프로젝트 초기화"
    echo "  ./scripts/manager.sh terraform-plan       - Terraform 계획 확인"
    echo "  ./scripts/manager.sh terraform-apply      - Terraform 인프라 생성/업데이트"
    echo "  ./scripts/manager.sh terraform-destroy    - Terraform 인프라 삭제"
    echo "  ./scripts/manager.sh list-lambdas          - 배포 가능한 Lambda 함수 목록"
    echo "  ./scripts/manager.sh deploy <lambda_name>  - 특정 Lambda 함수 배포"
    echo "  ./scripts/manager.sh deploy all            - 모든 Lambda 함수 배포"
    echo "  ./scripts/manager.sh re-init               - 설정 파일 재생성"
    echo "  ./scripts/manager.sh help                  - 이 도움말 출력"
    echo ""
    echo "배포 순서:"
    echo "  1. ./scripts/manager.sh init               (최초 1회)"
    echo "  2. ./scripts/manager.sh terraform-apply   (인프라 생성)"
    echo "  3. ./scripts/manager.sh deploy <lambda>   (Lambda 배포)"
    echo ""
    echo "예시:"
    echo "  ./scripts/manager.sh deploy ocr"
    echo "  ./scripts/manager.sh deploy all"
}

# 메인 실행 로직
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    
    case "$1" in
        "init")
            init_project
            ;;
        "list-lambdas")
            list_lambdas
            ;;
        "terraform-plan")
            terraform_plan
            ;;
        "terraform-apply")
            terraform_apply
            ;;
        "terraform-destroy")
            terraform_destroy
            ;;
        "deploy")
            if [ "$2" == "all" ]; then
                deploy_all
            elif [ -n "$2" ]; then
                deploy_single "$2"
            else
                log_error "배포할 Lambda 함수명을 지정해주세요."
                show_help
                exit 1
            fi
            ;;
        "re-init")
            re_init
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "알 수 없는 명령어: $1"
            show_help
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@" 