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
REPO_NAME=$(basename "$REPO_URL" .git)

if [ -d "$REPO_NAME/.git" ]; then
  echo "✅ Repository '$REPO_NAME' already exists. Skipping clone..."
else
  echo "📁 Cloning repository..."
  git clone "$REPO_URL"
fi

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
source ../.env
set +a

# Ensure AWS CLI is installed and in PATH
export PATH=$PATH:/usr/local/bin

if ! command -v aws &> /dev/null; then
  echo "🔧 Installing AWS CLI..."
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install
  echo "✅ AWS CLI installed."
else
  echo "✅ AWS CLI already present."
fi

# ----- Check if AWS credentials are configured -----
if ! aws sts get-caller-identity &>/dev/null; then
  echo "⚠️  AWS credentials not found. Launching 'aws configure'..."
  aws configure

  # Re-check if credentials were successfully set
  if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ AWS credentials still not configured. Exiting..."
    exit 1
  fi
fi

echo "✅ AWS credentials are configured."


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

# Check if the role already exists
if ! aws iam get-role --role-name S3ReadOnlyRole > /dev/null 2>&1; then
  echo "🔧 Creating role: S3ReadOnlyRole..."
  aws iam create-role \
  --role-name S3ReadOnlyRole \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name S3ReadOnlyRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

echo "✅ S3ReadOnlyRole created and policy attached"
else
  echo "✅ Role already exists: S3ReadOnlyRole"
fi


# ----- Create write-only policy JSON -----
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

# ----- Create custom write-only policy -----
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/S3WriteOnlyAccess"

if ! aws iam get-policy --policy-arn "$POLICY_ARN" > /dev/null 2>&1; then
  echo "🔧 Creating custom policy: S3WriteOnlyAccess..."
  aws iam create-policy \
    --policy-name S3WriteOnlyAccess \
    --policy-document file://s3-write-only-policy.json
  echo "✅ Custom policy 'S3WriteOnlyAccess' created"
else
  echo "✅ Policy already exists: S3WriteOnlyAccess"
fi

# ----- Create IAM role -----
if ! aws iam get-role --role-name S3WriteOnlyRole > /dev/null 2>&1; then
  echo "🔧 Creating IAM role: S3WriteOnlyRole..."
  aws iam create-role \
    --role-name S3WriteOnlyRole \
    --assume-role-policy-document file://trust-policy.json
  echo "✅ IAM role 'S3WriteOnlyRole' created"
else
  echo "✅ IAM role already exists: S3WriteOnlyRole"
fi

# ----- Attach policy to role (only if not already attached) -----
if ! aws iam list-attached-role-policies --role-name S3WriteOnlyRole | grep -q "S3WriteOnlyAccess"; then
  echo "🔗 Attaching policy to role..."
  aws iam attach-role-policy \
    --role-name S3WriteOnlyRole \
    --policy-arn "$POLICY_ARN"
  echo "✅ Policy attached to role"
else
  echo "✅ Policy already attached to role"
fi


# Create the instance profile only if it doesn't exist
if ! aws iam get-instance-profile --instance-profile-name S3WriteOnlyInstanceProfile > /dev/null 2>&1; then
  echo "🔧 Creating instance profile: S3WriteOnlyInstanceProfile..."
  aws iam create-instance-profile --instance-profile-name S3WriteOnlyInstanceProfile
else
  echo "✅ Instance profile already exists."
fi

# Add the role to the instance profile (only if not already attached)
if ! aws iam get-instance-profile --instance-profile-name S3WriteOnlyInstanceProfile | grep -q S3WriteOnlyRole; then
  echo "🔗 Associating role with instance profile..."
  aws iam add-role-to-instance-profile \
    --instance-profile-name S3WriteOnlyInstanceProfile \
    --role-name S3WriteOnlyRole
else
  echo "✅ Role already associated with instance profile."
fi

# Wait for IAM propagation
echo "⏳ Waiting for instance profile to propagate..."
sleep 10

# Check if instance profile is already associated with the instance
EXISTING_PROFILE=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" \
  --output text 2>/dev/null)

if [[ "$EXISTING_PROFILE" == *"S3WriteOnlyInstanceProfile"* ]]; then
  echo "✅ Instance already associated with the profile."
else
  echo "🔗 Associating instance profile with EC2 instance..."
  aws ec2 associate-iam-instance-profile \
    --instance-id "$INSTANCE_ID" \
    --iam-instance-profile Name=S3WriteOnlyInstanceProfile
fi


# Check if required env vars are set
if [[ -z "$LOG_BUCKET_NAME" || -z "$REGION" ]]; then
  echo "❌ LOG_BUCKET_NAME or REGION is not set in .env. Exiting."
  exit 1
fi

echo "🚀 Checking if bucket '$LOG_BUCKET_NAME' exists..."

# Check if bucket exists
if aws s3api head-bucket --bucket "$LOG_BUCKET_NAME" 2>/dev/null; then
  echo "✅ Bucket '$LOG_BUCKET_NAME' already exists. Skipping creation."
else
  echo "🚀 Creating private S3 bucket: $LOG_BUCKET_NAME in region $REGION..."

  aws s3api create-bucket \
    --bucket "$LOG_BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"

  echo "✅ Bucket '$LOG_BUCKET_NAME' created."
fi

# Apply public access block config
aws s3api put-public-access-block \
  --bucket "$LOG_BUCKET_NAME" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "✅ Bucket '$LOG_BUCKET_NAME' is private."

# Prepare log variables
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
APP_LOG_PATH="/home/ubuntu/app.log"  # <-- change if needed

echo "📤 Uploading logs to S3 bucket: $LOG_BUCKET_NAME"

# Upload cloud-init log
if [[ -f "/var/log/cloud-init.log" ]]; then
  aws s3 cp /var/log/cloud-init.log s3://$LOG_BUCKET_NAME/logs/$INSTANCE_ID-cloud-init-$TIMESTAMP.log
  echo "✅ cloud-init.log uploaded"
else
  echo "⚠️ /var/log/cloud-init.log not found"
fi

# Upload app log
if [[ -f "$APP_LOG_PATH" ]]; then
  aws s3 cp "$APP_LOG_PATH" s3://$LOG_BUCKET_NAME/app/logs/$INSTANCE_ID-app-$TIMESTAMP.log
  echo "✅ App log uploaded"
else
  echo "⚠️ App log not found at $APP_LOG_PATH"
fi

# Set lifecycle policy to delete logs after 7 days
echo "🗑 Setting lifecycle policy to delete logs after 7 days..."

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

echo "✅ Lifecycle policy set."

# List uploaded logs
echo "📂 Listing uploaded logs:"
aws s3 ls s3://$LOG_BUCKET_NAME/logs/
aws s3 ls s3://$LOG_BUCKET_NAME/app/logs/

echo "✅ Script execution completed."
