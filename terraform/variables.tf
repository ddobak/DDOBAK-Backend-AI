# AWS 설정
variable "aws_profile" {
  description = "AWS CLI 프로필명"
  type        = string
  default     = "ddobak"
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

# 환경 설정
variable "environment" {
  description = "환경명 (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# 프로젝트 설정
variable "project_name" {
  description = "프로젝트명"
  type        = string
  default     = "ddobak"
} 