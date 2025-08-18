output "tf_state_bucket" {
  description = "S3 bucket name for Terraform remote state"
  value       = aws_s3_bucket.tf_state.bucket
}

output "tf_lock_table" {
  description = "DynamoDB table name for Terraform state locks"
  value       = aws_dynamodb_table.tf_locks.name
}
