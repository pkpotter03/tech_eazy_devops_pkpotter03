output "instance_id" {
  value = aws_instance.app.id
}

output "public_ip" {
  value = aws_instance.app.public_ip
}

output "log_bucket" {
  value = aws_s3_bucket.logs.bucket
}

output "instance_profile_arn" {
  value = aws_iam_instance_profile.write_only_profile.arn
}

output "stage_info" {
  description = "Stage-specific information"
  value = {
    stage = var.stage
    environment = var.stage
    instance_type = var.instance_type
    app_port = var.app_port
    github_repo_type = var.github_repo_type
  }
}

output "resource_names" {
  description = "Names of created resources"
  value = {
    security_group = aws_security_group.app_sg.name
    iam_role = aws_iam_role.s3_write_only_role.name
    instance_profile = aws_iam_instance_profile.write_only_profile.name
    s3_bucket = aws_s3_bucket.logs.bucket
  }
}

output "security_group_id" {
  description = "Security group ID"
  value = aws_security_group.app_sg.id
}

output "iam_role_arn" {
  description = "IAM role ARN"
  value = aws_iam_role.s3_write_only_role.arn
}
