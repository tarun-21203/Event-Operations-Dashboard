output "api_url" {
  value = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${data.aws_region.current.id}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}"
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "queue_url" {
  value = aws_sqs_queue.main_queue.id
}

output "archive_bucket_name" {
  value = aws_s3_bucket.archive.bucket
}