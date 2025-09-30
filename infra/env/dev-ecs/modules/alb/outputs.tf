output "lb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

output "lb_name" {
  description = "Name of the Application Load Balancer"
  value       = aws_lb.this.name
}

output "lb_dns_name" {
  description = "Public DNS name of the ALB"
  value       = aws_lb.this.dns_name
}

output "lb_arn_suffix" {
  description = "ARN suffix of the ALB"
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.this.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group"
  value       = aws_lb_target_group.this.arn_suffix
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener (null if disabled)"
  value       = length(aws_lb_listener.https) > 0 ? aws_lb_listener.https[0].arn : null
}

output "log_bucket_name" {
  description = "Name of the ALB access logs bucket"
  value       = aws_s3_bucket.logs.id
}
