locals {
  name  = "assignment4-${lower(var.stage)}"
  tags  = merge(var.tags, { 
    Stage = var.stage, 
    Project = "DevOps-Assignment-4",
    Environment = var.stage,
    ManagedBy = "Terraform",
    Owner = "DevOps Team",
    CostCenter = "assignment4"
  })
}

# ----- AMI (Ubuntu 22.04 LTS) -----
data "aws_ami" "ubuntu_jammy" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ----- Security Group -----
resource "aws_security_group" "app_sg" {
  name        = "${local.name}-sg"
  description = "Security group for ${var.stage} stage - Allow SSH and HTTP on port ${var.app_port}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from anywhere (restrict in real projects)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP on port ${var.app_port}"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags

  # Add lifecycle policy to prevent accidental deletion
  lifecycle {
    prevent_destroy = var.stage == "prod" ? true : false
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ----- S3 bucket for logs (private + lifecycle) -----
resource "aws_s3_bucket" "logs" {
  bucket = var.log_bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "DeleteLogs"
    status = "Enabled"
    filter { prefix = "logs/" }
    expiration {
      days = 7
    }
  }
  rule {
    id     = "DeleteAppLogs"
    status = "Enabled"
    filter { prefix = "app/logs/" }
    expiration {
      days = 7
    }
  }
}

# ----- IAM: Write-only policy for S3 (as per Assignment 2) -----
data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "s3_write_only" {
  name        = "S3WriteOnlyAccess-${var.stage}"
  description = "Allow PutObject and CreateBucket; deny reads for ${var.stage} stage"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowBucketCreation",
        Effect = "Allow",
        Action = ["s3:CreateBucket"],
        Resource = "*"
      },
      {
        Sid    = "AllowPutObject",
        Effect = "Allow",
        Action = ["s3:PutObject"],
        Resource = "arn:aws:s3:::*/*"
      },
      {
        Sid    = "DenyReadAccess",
        Effect = "Deny",
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObjectVersion"
        ],
        Resource = "*"
      }
    ]
  })
  tags = local.tags
}

# Optional: S3 ReadOnly role (re-creating parity with your A2)
resource "aws_iam_role" "s3_read_only_role" {
  name               = "S3ReadOnlyRole-${var.stage}"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "read_only_attach" {
  role       = aws_iam_role.s3_read_only_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Write-only role (used by EC2)
resource "aws_iam_role" "s3_write_only_role" {
  name               = "S3WriteOnlyRole-${var.stage}"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "write_only_attach" {
  role       = aws_iam_role.s3_write_only_role.name
  policy_arn = aws_iam_policy.s3_write_only.arn
}

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_instance_profile" "write_only_profile" {
  name = "S3WriteOnlyInstanceProfile-${var.stage}"
  role = aws_iam_role.s3_write_only_role.name
  tags = local.tags
}

# ----- EC2 instance (secure profile attached here) -----
resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu_jammy.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.write_only_profile.name

  # Enhanced user_data with stage-specific configuration
  user_data = <<-EOF
              #!/bin/bash
              set -e
              echo "Cloud-init started for stage: ${var.stage} at $(date)" | tee /var/log/cloud-init-${var.stage}.log
              
              # Create stage-specific directories
              mkdir -p /opt/app/config
              mkdir -p /opt/app/logs
              
              # Set stage environment variable
              echo "STAGE=${var.stage}" >> /etc/environment
              echo "APP_PORT=${var.app_port}" >> /etc/environment
              echo "ENVIRONMENT=${var.stage}" >> /etc/environment
              
              # Install basic tools
              apt-get update -y
              apt-get install -y curl wget unzip
              
              echo "Cloud-init completed for stage: ${var.stage} at $(date)" | tee -a /var/log/cloud-init-${var.stage}.log
              EOF

  tags = merge(local.tags, {
    Name = "${local.name}-ec2"
  })

  # Add lifecycle policy to prevent accidental deletion in production
  lifecycle {
    prevent_destroy = var.stage == "prod" ? true : false
  }
}


