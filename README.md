# 📦 EC2 Spring Boot Deployment & S3 Integration

This project automates the deployment of a Spring Boot application on an AWS EC2 instance, installs necessary dependencies, and integrates with AWS IAM and S3 using AWS CLI.

---

## 🔧 Prerequisites

* AWS Account with programmatic access
* AWS CLI installed and configured (`aws configure`)
* `.env` file with required secrets
* A `Dev_config` or similar stage config file
* A GitHub repo with a Spring Boot project and a working `/hello` endpoint
* EC2 instance (Ubuntu) already launched and accessible

---

## 📁 Project Structure

```
.
├── deploy.sh              # Main deployment script
├── dev_config             # Stage-specific configuration
├── .env                   # Environment variables (AWS, app config)
├── trust-policy.json      # IAM trust policy (auto-generated)
├── s3-write-only-policy.json # S3 write-only custom policy (auto-generated)
```

---

## ⚙️ Environment Setup

### .env file

Define the following keys in your `.env` file:

```dotenv
AWS_ACCOUNT_ID=your_aws_account_id
REGION=ap-south-1
LOG_BUCKET_NAME=your-log-bucket
INSTANCE_ID=i-xxxxxxxxxxxxxxxxx
```

### dev\_config file

```bash
REPO_URL=https://github.com/your-user/your-spring-app.git
JAVA_VERSION=21
MAVEN_VERSION=3.9.1
APP_PORT=80
SHUTDOWN_AFTER_MINUTES=60
```
---

## ✅ Script Features

### Spring Boot App Deployment

* Installs dependencies (Java, Maven, Git)
* Clones project from GitHub
* Builds with Maven
* Starts app in background
* Verifies endpoint `http://<EC2_PUBLIC_IP>/hello`

### AWS IAM & S3 Setup

* Creates:

  * `S3ReadOnlyRole`
  * `S3WriteOnlyAccess` policy
  * `S3WriteOnlyRole`
  * `S3WriteOnlyInstanceProfile`
* Attaches roles and policies
* Associates instance profile with EC2 instance

### Logging

* Uploads `cloud-init.log` and `app.log` to S3
* Sets S3 lifecycle rule to delete logs after 7 days

---

## 👤 How to Add IAM User Permissions

To allow an IAM user to manage EC2, S3, and IAM resources, follow these steps:

### Step 1: Create IAM User

* Go to IAM Console → Users → Add User
* Choose a username
* Select **Programmatic access** (for CLI)

### Step 2: Attach Permissions Policies

Choose one of the following:

#### Option A: Administrator Access (for full control)

* Attach policy: `AdministratorAccess`

#### Option B: Limited Access (Recommended)

Attach these policies:

* `AmazonEC2FullAccess`
* `AmazonS3FullAccess`
* `IAMFullAccess`
* `CloudWatchLogsFullAccess`

> You can also create a custom IAM policy that grants limited access only to specific actions or resources.

### Step 3: Save Access Keys

* After creation, download the `.csv` file with **Access Key ID** and **Secret Access Key**
* Store them securely, and use them in `.env`

---

## 🚀 Deployment Instructions

### 1. Make script executable

```bash
chmod +x deploy.sh
```

### 2. Run the script with a stage

```bash
./deploy.sh Dev
```

This will:

* Load stage config (e.g., `dev_config`)
* Install Java and Maven
* Clone and build the Spring Boot app
* Run the app on EC2 on port defined in config
* Create/verify IAM roles and policies
* Upload logs to private S3 bucket
* Schedule EC2 auto-shutdown


---

## 🧪 Sample Output

```
✅ Loaded config for stage: Dev
✅ Maven installed successfully
✅ App is running correctly!
✅ AWS credentials are configured.
✅ Bucket 'my-bucket' is private.
✅ App log uploaded
✅ Lifecycle policy set.
✅ Script execution completed.
```

---

## 📌 Notes

* To stop the app early, run:

```bash
sudo shutdown now
```

* If any IAM resource already exists, script skips creation.
* Logs are stored in:

  * `s3://<bucket-name>/logs/`
  * `s3://<bucket-name>/app/logs/`

---

## 🧹 Cleanup

To remove IAM roles, policies, and instance profile:

```bash
aws iam remove-role-from-instance-profile --instance-profile-name S3WriteOnlyInstanceProfile --role-name S3WriteOnlyRole
aws iam delete-instance-profile --instance-profile-name S3WriteOnlyInstanceProfile
aws iam detach-role-policy --role-name S3WriteOnlyRole --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/S3WriteOnlyAccess
aws iam delete-role --role-name S3WriteOnlyRole
aws iam delete-policy --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/S3WriteOnlyAccess
```

---

## 📬 Contact

For issues or contributions, raise a PR or contact the project maintainer.
