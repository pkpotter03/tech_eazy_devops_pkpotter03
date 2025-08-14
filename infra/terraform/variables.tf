variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "stage" {
  description = "Stage name (Dev/Prod)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH"
  type        = string
}

variable "log_bucket_name" {
  description = "S3 bucket for logs (must be globally unique)"
  type        = string
}

variable "app_port" {
  description = "App port (your Spring app maps to 80 via the script)"
  type        = number
  default     = 80
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
