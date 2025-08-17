# DevOps Assignment 3 - Automated Spring App Deployment

This repository demonstrates **infrastructure provisioning and automated deployment** of a Spring Boot application using **Terraform** and **GitHub Actions**. It implements EC2 instance provisioning, IAM roles, S3 bucket logging, deployment scripts, and health checks.

---

## 📁 Folder Structure

```
.
├── infra/
├── terraform/
│   ├── main.tf # Terraform resources (EC2, IAM, S3, Security Group)
│   ├── variables.tf # Terraform input variables
│   ├── outputs.tf # Terraform outputs
│   └── provider.tf # AWS provider config
├── .github/
│   └── workflows/
│       └── deploy.yml # GitHub Actions workflow: provision, deploy, health check
└── scripts/
    ├── deploy.sh # Deployment script for EC2
    ├── Dev_config # Stage-specific config (Dev)
    └── .env.example # Example environment variables
```


---

## 🔹 Overview

1. **Terraform Infrastructure**
   - **EC2 Instance** with secure IAM instance profile.
   - **Security Group** allowing SSH (22) and HTTP (80).
   - **S3 Bucket** for log storage (private, lifecycle rules for auto-delete after 7 days).
   - **IAM Roles**:
     - Write-only role attached to EC2 for uploading logs.
     - Optional S3 Read-only role.
   
2. **GitHub Actions Workflow**
   - Triggered on:
     - Push to `main`.
     - Tag like `deploy-dev` or `deploy-prod`.
     - Manual workflow dispatch.
   - Jobs:
     1. **Provision:** Launch EC2 using Terraform.
     2. **Deploy:** SSH into EC2, run `deploy.sh`, upload config and `.env`.
     3. **Health Check:** Poll `/hello` endpoint; fetch logs on failure.
   
3. **Deployment Script (`deploy.sh`)**
   - Installs dependencies: Java, Maven, AWS CLI.
   - Clones the Spring Boot repository and builds the app.
   - Runs the app in the background.
   - Uploads `app.log` and `cloud-init.log` to S3.
   - Automatically shuts down the EC2 instance after configured minutes.

---

## ⚙️ Prerequisites

- AWS account with access keys configured in GitHub Secrets:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_REGION`
- SSH private key in GitHub Secrets: `SSH_PRIVATE_KEY`
- Terraform installed locally (for testing) or via GitHub Actions.
- GitHub repo contains your Spring Boot application URL in `.env` or config.

---

## 🚀 Usage

### 1️⃣ Configure Secrets

In your GitHub repository, add the following secrets:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `SSH_PRIVATE_KEY`
- `TF_VAR_key_name` (EC2 Key Pair name)
- `TF_VAR_log_bucket_name` (S3 bucket for logs)

### 2️⃣ Trigger Deployment

- **Push to main branch** → deploys Dev by default.
- **Push a tag** like `deploy-dev` or `deploy-prod` → deploys corresponding stage.
- **Manual trigger** via GitHub Actions → select `stage` (Dev/Prod).

### 3️⃣ Workflow Steps

1. Terraform provisions EC2, IAM roles, S3 bucket.
2. GitHub Action uploads `deploy.sh`, stage config, `.env`.
3. `deploy.sh` installs dependencies, builds app, runs it, uploads logs to S3.
4. Health check ensures app is reachable on port 80.
5. Instance automatically shuts down after defined minutes.

---

## 📌 Notes

- Stage configs (`Dev_config`, `Prod_config`) define:
  - `JAVA_VERSION`
  - `MAVEN_VERSION`
  - `REPO_URL`
  - `APP_PORT`
  - `SHUTDOWN_AFTER_MINUTES`
- Logs are uploaded to S3 bucket with separate folders:
  - `/logs/` for cloud-init logs
  - `/app/logs/` for application logs
- Security best practices:
  - Restrict SSH access to specific IPs in production.
  - Never expose private keys publicly.
  
---