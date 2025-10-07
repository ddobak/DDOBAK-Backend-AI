# SQS 큐 "자체"를 만듬 (Bedrock 결과 전송용)
resource "aws_sqs_queue" "analysis_results" {
  name                      = "${var.project_name}-${var.environment}-analysis-results"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 5
  sqs_managed_sse_enabled    = true

  tags = local.common_tags
}

output "sqs_analysis_results_arn" {
  description = "ARN of the analysis results SQS queue"
  value       = aws_sqs_queue.analysis_results.arn
}

output "sqs_analysis_results_url" {
  description = "URL of the analysis results SQS queue"
  value       = aws_sqs_queue.analysis_results.id
}

