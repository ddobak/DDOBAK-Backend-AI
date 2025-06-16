# Terraform 설정
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider 설정
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# 데이터 소스: 현재 AWS 계정 정보
data "aws_caller_identity" "current" {}

# 데이터 소스: AWS 리전 정보
data "aws_region" "current" {}

# 공통 태그
locals {
  common_tags = {
    Project     = "ddobak"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
} 