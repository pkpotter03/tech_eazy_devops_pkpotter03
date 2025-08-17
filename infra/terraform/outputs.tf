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
