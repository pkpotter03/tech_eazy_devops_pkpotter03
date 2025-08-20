variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "stage" {
  description = "Stage name (dev/qa/prod)"
  type        = string
  validation {
    condition     = contains(["dev", "qa", "prod"], lower(var.stage))
    error_message = "Stage must be one of: dev, qa, prod."
  }
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
  description = "Application port"
  type        = number
  default     = 8080
}

variable "github_token" {
  description = "GitHub Personal Access Token for private repos"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_repo_type" {
  description = "GitHub repository type (public/private)"
  type        = string
  default     = "public"
  validation {
    condition     = contains(["public", "private"], var.github_repo_type)
    error_message = "GitHub repo type must be either 'public' or 'private'."
  }
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
