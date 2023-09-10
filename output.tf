output "sqs_queue_url" {
  value = module.sqs.sqs_queue_url
}

output "aws_cli_enqueue_command" {
  value = "aws sqs send-message --queue-url ${module.sqs.sqs_queue_url} --message-body 'Hello'"
}
