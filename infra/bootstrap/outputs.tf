output "s3_bucket_name" {
  value       = aws_s3_bucket.tf_state.id
  description = "S3 bucket used to store Terraform remote state"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.tf_locks.name
  description = "DynamoDB table used to lock Terraform state"
}
