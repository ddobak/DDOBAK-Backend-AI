# Terraform (ECR, Lambda, SQS, Destinations)

구성 요약
- ECR, Lambda(이미지), IAM, CloudWatch Logs(보존 14일)
- SQS `analysis_results`(성공), `analysis_results_dlq`(실패)
- Destinations: `bedrock_lambda` on_success → 성공 큐, on_failure → 실패 큐
- 이벤트 소스 매핑: 성공 큐 → `analysis_result_loader`
- 현재 DLQ는 자동 소비 안 함
- CloudWatch Logs에서 Lambda 실행 로그 확인