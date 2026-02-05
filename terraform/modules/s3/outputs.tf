output "bucket_ids" {
  description = "생성된 S3 버킷 ID 맵"
  value       = { for k, v in aws_s3_bucket.this : k => v.id }
}

output "bucket_arns" {
  description = "생성된 S3 버킷 ARN 맵"
  value       = { for k, v in aws_s3_bucket.this : k => v.arn }
}

output "cloudtrail_bucket_id" {
  value = aws_s3_bucket.this["cloudtrail"].id
}

output "logs_bucket_id" {
  value = aws_s3_bucket.this["logs"].id
}
