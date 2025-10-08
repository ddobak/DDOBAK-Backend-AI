# 실패 큐(DLQ): analysis_results_dlq
resource "aws_sqs_queue" "analysis_results_dlq" {
  name                       = "${var.project_name}-${var.environment}-analysis-results-dlq"
  message_retention_seconds  = 1209600
  sqs_managed_sse_enabled    = true

  tags = local.common_tags
}

# 메인 큐: analysis_results
# redrive policy로 5번 이상 실패 시 DLQ로 전송
resource "aws_sqs_queue" "analysis_results" {
  name                      = "${var.project_name}-${var.environment}-analysis-results"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 5
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.analysis_results_dlq.arn
    maxReceiveCount     = 5
  })

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

output "sqs_analysis_results_dlq_arn" {
  description = "ARN of the analysis results DLQ"
  value       = aws_sqs_queue.analysis_results_dlq.arn
}

