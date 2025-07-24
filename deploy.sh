#!/bin/bash

set -e

# ---------- Assignment 1: Deploy Spring Boot App on EC2 ----------

# ---------- Step 1: Load Stage Config ----------
STAGE=$1
if [[ -z "$STAGE" ]]; then
  echo "❗ Please provide a stage name like: ./deploy.sh Dev"
  exit 1
fi

CONFIG_FILE="./${STAGE,,}_config"  # lowercase
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❗ Config file not found: $CONFIG_FILE"
  exit 1
fi

source "$CONFIG_FILE"
echo "✅ Loaded config for stage: $STAGE"


# ---------- Step 2: Install System Dependencies ----------
echo "🛠 Updating and installing required packages..."
sudo apt update -y
sudo apt install -y curl unzip git iptables openjdk-${JAVA_VERSION}-jdk

# ---------- Step 3: Install Maven ----------
echo "📦 Installing Maven $MAVEN_VERSION..."
wget https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip
unzip apache-maven-${MAVEN_VERSION}-bin.zip
# Clean up previous Maven installation if it exists
sudo rm -rf /opt/maven/apache-maven-3.9.11
sudo mv apache-maven-3.9.11 /opt/maven/
# Create symlink only if it doesn't already exist
if ! command -v mvn &> /dev/null; then
  sudo ln -s /opt/maven/bin/mvn /usr/bin/mvn
else
  echo "ℹ️ Maven is already linked to /usr/bin/mvn"
fi
echo "✅ Maven installed successfully"
mvn -v


# ---------- Step 4: Clone and Build Spring App ----------
echo "📁 Cloning repository..."
git clone "$REPO_URL"
REPO_NAME=$(basename "$REPO_URL" .git)
cd "$REPO_NAME"

echo "🧱 Building project with Maven..."
mvn clean package


# ---------- Step 5: Start Spring App ----------
echo "🚀 Starting Spring Boot app on port $APP_PORT"
nohup sudo java -jar target/*.jar --server.port=$APP_PORT > app.log 2>&1 &

# ---------- Step 7: Test App Endpoint ----------
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
APP_URL="http://${PUBLIC_IP}/hello"
echo "🔍 Checking endpoint: $APP_URL"
sleep 10

if curl --silent "$APP_URL" | grep -q "Hello from Spring MVC!"; then
  echo "✅ App is running correctly!"
else
  echo "❌ App failed to respond as expected."
fi


# ---------- Step 8: Auto Shutdown ----------
echo "⏱ Scheduling EC2 shutdown in $SHUTDOWN_AFTER_MINUTES minutes..."
sudo shutdown -h +$SHUTDOWN_AFTER_MINUTES


# ---------- Assignment 2 ----------

# Load env file
set -a
source source ../.env
set +a

# ----- Create trust policy file -----
cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

echo "✅ Trust policy created"

# ----- Create S3ReadOnlyRole -----
aws iam create-role \
  --role-name S3ReadOnlyRole \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name S3ReadOnlyRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

echo "✅ S3ReadOnlyRole created and policy attached"

# ----- Create write-only policy -----
cat <<EOF > s3-write-only-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowBucketCreation",
      "Effect": "Allow",
      "Action": "s3:CreateBucket",
      "Resource": "*"
    },
    {
      "Sid": "AllowPutObject",
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::*/*"
    },
    {
      "Sid": "DenyReadAccess",
      "Effect": "Deny",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetObjectVersion"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create the custom write-only policy
aws iam create-policy \
  --policy-name S3WriteOnlyAccess \
  --policy-document file://s3-write-only-policy.json

echo "✅ Custom policy 'S3WriteOnlyAccess' created"

# Attach to a role
aws iam create-role \
  --role-name S3WriteOnlyRole \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name S3WriteOnlyRole \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/S3WriteOnlyAccess

echo "✅ S3WriteOnlyRole created and policy attached"

# Create an instance profile and associate it with the role
aws iam create-instance-profile --instance-profile-name S3WriteOnlyInstanceProfile

# Associate the role with the instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name S3WriteOnlyInstanceProfile \
  --role-name S3WriteOnlyRole

# Associate the instance profile with the EC2 instance
aws ec2 associate-iam-instance-profile \
  --instance-id "$INSTANCE_ID" \
  --iam-instance-profile Name=S3WriteOnlyInstanceProfile

# Check for BUCKET_NAME
if [ -z "$BUCKET_NAME" ]; then
  echo "❌ BUCKET_NAME is not set in .env. Exiting."
  exit 1
fi

echo "🚀 Creating private S3 bucket: $BUCKET_NAME in region $REGION..."

# Create bucket
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

# Make bucket private (by disabling public access)
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "✅ Bucket '$BUCKET_NAME' created and set to private."

# upload logs to S3
BUCKET_NAME=${LOG_BUCKET_NAME:-""}
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

if [[ -z "$BUCKET_NAME" ]]; then
  echo "❌ S3 bucket name not set. Exiting."
  exit 1
fi

echo "📤 Uploading logs to S3 bucket: $BUCKET_NAME"

# Upload cloud-init system log
aws s3 cp /var/log/cloud-init.log s3://$BUCKET_NAME/logs/$INSTANCE_ID-cloud-init-$TIMESTAMP.log

# ✅ Upload app logs
APP_LOG_PATH="/home/ubuntu/app.log"  # <-- update if needed

if [[ -f "$APP_LOG_PATH" ]]; then
  aws s3 cp "$APP_LOG_PATH" s3://$BUCKET_NAME/app/logs/$INSTANCE_ID-app-$TIMESTAMP.log
else
  echo "⚠️ App log not found at $APP_LOG_PATH"
fi

# Set lifecycle policy to delete logs after 7 days
echo "🗑 Setting lifecycle policy to delete logs after 7 days"
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$LOG_BUCKET_NAME" \
  --lifecycle-configuration '{
    "Rules": [
      {
        "ID": "DeleteOldLogs",
        "Filter": {
          "Prefix": "logs/"
        },
        "Status": "Enabled",
        "Expiration": {
          "Days": 7
        }
      },
      {
        "ID": "DeleteAppLogs",
        "Filter": {
          "Prefix": "app/logs/"
        },
        "Status": "Enabled",
        "Expiration": {
          "Days": 7
        }
      }
    ]
  }'

echo "✅ Logs uploaded and lifecycle policy set."

# List logs in S3 bucket
aws s3 ls s3://$LOG_BUCKET_NAME/logs/
aws s3 ls s3://$LOG_BUCKET_NAME/app/logs/

# End of script

