output "key_id" {
  value = aws_kms_key.vpce.id
}

output "key_arn" {
  value = aws_kms_key.vpce.arn
}
