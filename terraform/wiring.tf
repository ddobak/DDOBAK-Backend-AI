# bedrock_lambda 성공 시 SQS로 결과를 전송 (Lambda Destinations)
resource "aws_lambda_event_invoke_config" "bedrock_success_to_sqs" {
  function_name = module.lambdas["bedrock_lambda"].lambda_function_name

  destination_config {
    on_success {
      destination = aws_sqs_queue.analysis_results.arn
    }
  }

  maximum_retry_attempts = 0
}

# SQS → analysis_result_loader 트리거 (이벤트 소스 매핑)
resource "aws_lambda_event_source_mapping" "sqs_to_analysis_result_loader" {
  event_source_arn                   = aws_sqs_queue.analysis_results.arn
  function_name                      = module.lambdas["analysis_result_loader"].lambda_function_arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  enabled                            = true
}

