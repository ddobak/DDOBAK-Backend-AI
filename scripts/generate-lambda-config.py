#!/usr/bin/env python3
"""
Lambda 설정 자동 생성 스크립트
각 Lambda의 lambda.yaml 파일을 읽어서 Terraform 변수를 생성합니다.
"""

import os
import yaml
import json
from pathlib import Path
from typing import Dict, Any

def load_lambda_config(lambda_dir: Path) -> Dict[str, Any]:
    """Lambda 디렉터리에서 설정을 로드합니다."""
    config_file = lambda_dir / "lambda.yaml"
    if not config_file.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_file}")
    
    with open(config_file, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)

def generate_terraform_vars(lambdas_dir: Path) -> Dict[str, Any]:
    """모든 Lambda 설정을 읽어서 Terraform 변수를 생성합니다."""
    terraform_vars = {
        "lambdas": {}
    }
    
    # lambdas 디렉터리 내의 모든 하위 디렉터리 찾기
    for lambda_dir in lambdas_dir.iterdir():
        if lambda_dir.is_dir() and lambda_dir.name != "__pycache__":
            try:
                config = load_lambda_config(lambda_dir)
                lambda_name = config["name"]
                
                terraform_vars["lambdas"][lambda_name] = {
                    "function_name": config["function_name"],
                    "ecr_repository": config["ecr_repository"],
                    "memory_size": config["memory_size"],
                    "timeout": config["timeout"],
                    "environment_variables": config.get("environment_variables", {}),
                    "cors_origins": config.get("cors_origins", ["*"]),
                    "description": config.get("description", "")
                }
                
                print(f"✅ Loaded configuration for: {lambda_name}")
                
            except Exception as e:
                print(f"❌ Error loading config for {lambda_dir.name}: {e}")
                continue
    
    return terraform_vars

def save_terraform_vars(vars_data: Dict[str, Any], output_file: Path):
    """Terraform 변수를 JSON 파일로 저장합니다."""
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(vars_data, f, indent=2, ensure_ascii=False)
    
    print(f"💾 Terraform variables saved to: {output_file}")

def main():
    """메인 함수"""
    # 프로젝트 루트 디렉터리 찾기
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    lambdas_dir = project_root / "lambdas"
    output_file = project_root / "terraform" / "lambda_configs.json"
    
    if not lambdas_dir.exists():
        print(f"❌ Lambdas directory not found: {lambdas_dir}")
        return 1
    
    print("🔍 Scanning for Lambda configurations...")
    print(f"📁 Lambdas directory: {lambdas_dir}")
    
    try:
        # Terraform 변수 생성
        terraform_vars = generate_terraform_vars(lambdas_dir)
        
        if not terraform_vars["lambdas"]:
            print("⚠️ No Lambda configurations found!")
            return 1
        
        # 출력 디렉터리 생성
        output_file.parent.mkdir(exist_ok=True)
        
        # 파일 저장
        save_terraform_vars(terraform_vars, output_file)
        
        print(f"\n📊 Summary:")
        print(f"   Found {len(terraform_vars['lambdas'])} Lambda functions:")
        for name in terraform_vars["lambdas"].keys():
            print(f"   - {name}")
        
        return 0
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1

if __name__ == "__main__":
    exit(main()) 