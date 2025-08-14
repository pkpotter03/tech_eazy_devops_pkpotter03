terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Optional: uncomment to use an S3 backend for state
  # backend "s3" {
  #   bucket = "<your-tf-state-bucket>"
  #   key    = "assignment3/terraform.tfstate"
  #   region = var.region
  # }
}

provider "aws" {
  region = var.region
}
