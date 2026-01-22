resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-${var.env}-trail"
  s3_bucket_name                = var.cloudtrail_bucket_id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  # 다른 파일에서 만든 리소스를 참조
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_to_cloudwatch.arn

  tags = { Name = "${var.project_name}-trail" }
}