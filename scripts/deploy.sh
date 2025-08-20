#!/bin/bash
set -e

# Multi-Stage Deployment Script (Assignment 4)
# Supports: dev, qa, prod stages with private/public GitHub repo handling

# 1️⃣ Load stage configuration
STAGE=$1
if [[ -z "$STAGE" ]]; then
  echo "❗ Please provide a stage name like: ./deploy.sh Dev"
  exit 1
fi

STAGE_LOWER=$(echo "$STAGE" | tr '[:upper:]' '[:lower:]')
CONFIG_FILE="./${STAGE_LOWER}_config"
APP_CONFIG_FILE="./app-config.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❗ Config file not found: $CONFIG_FILE"
  exit 1
fi

if [[ ! -f "$APP_CONFIG_FILE" ]]; then
  echo "❗ App config file not found: $APP_CONFIG_FILE"
  exit 1
fi

source "$CONFIG_FILE"
echo "✅ Loaded config for stage: $STAGE (Environment: $ENVIRONMENT)"

# 2️⃣ Install system dependencies
echo "🛠 Installing system dependencies for stage: $STAGE..."
sudo apt update -y
sudo apt install -y curl unzip git openjdk-${JAVA_VERSION}-jdk

# 3️⃣ Install Maven
echo "📦 Installing Maven $MAVEN_VERSION for stage: $STAGE..."
wget https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip
unzip -o apache-maven-${MAVEN_VERSION}-bin.zip
sudo mv apache-maven-${MAVEN_VERSION} /opt/maven/
sudo ln -sf /opt/maven/bin/mvn /usr/bin/mvn
echo "✅ Maven version: $(mvn -v | head -n 1)"

# 4️⃣ Install AWS CLI
if ! command -v aws &> /dev/null; then
    echo "📦 Installing AWS CLI for stage: $STAGE..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -o awscliv2.zip
    sudo ./aws/install
    export PATH=$PATH:/usr/local/bin
    echo "✅ AWS CLI installed: $(aws --version)"
else
    echo "✅ AWS CLI already installed: $(aws --version)"
fi

# 5️⃣ Handle GitHub repository access based on stage
echo "🔐 Setting up GitHub access for stage: $STAGE (Repo type: $REPO_TYPE)..."

if [[ "$REPO_TYPE" == "private" ]]; then
    echo "🔒 Private repository detected for stage: $STAGE"
    
    # Check if GitHub token is available
    if [[ -n "$GITHUB_TOKEN" ]]; then
        echo "✅ Using GitHub token for private repo access"
        # Configure git with token
        git config --global url."https://${GITHUB_TOKEN}:x-oauth-basic@github.com/".insteadOf "https://github.com/"
    else
        echo "❌ GitHub token required for private repository access"
        echo "Please set GITHUB_TOKEN environment variable"
        exit 1
    fi
else
    echo "🌐 Public repository detected for stage: $STAGE"
fi

# 6️⃣ Clone & build Spring Boot app
echo "📁 Cloning repository for stage: $STAGE..."
REPO_NAME=$(basename "$REPO_URL" .git)
git clone "$REPO_URL" || true
cd "$REPO_NAME"

# Copy stage-specific configuration
echo "⚙️ Applying stage-specific configuration for $STAGE..."
sudo mkdir -p /opt/app/config
sudo cp ../app-config.json /opt/app/config/
sudo chown -R ubuntu:ubuntu /opt/app/

echo "🧱 Building project with Maven for stage: $STAGE..."
mvn clean package

# 7️⃣ Run the app with stage-specific configuration
echo "🚀 Starting Spring Boot app for stage: $STAGE on port $APP_PORT..."
nohup java -jar target/*.jar \
    --server.port=$APP_PORT \
    --spring.config.location=file:/opt/app/config/app-config.json \
    > app.log 2>&1 &

echo "✅ App is running on port $APP_PORT for stage: $STAGE"

# 8️⃣ Test app health
echo "🔍 Testing app health for stage: $STAGE..."
sleep 15
if curl -f "http://$(curl -s http://checkip.amazonaws.com):$APP_PORT/hello"; then
    echo "✅ App is reachable on port $APP_PORT for stage: $STAGE"
else
    echo "❌ App is not reachable on port $APP_PORT for stage: $STAGE"
    exit 1
fi

# 9️⃣ Upload logs to stage-specific S3 folders
echo "📤 Uploading logs to S3 for stage: $STAGE..."
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
LOG_BUCKET_NAME="my-private-devops-bucket-logs"

# Create stage-specific S3 paths
STAGE_LOG_PATH="logs/${STAGE_LOWER}"
APP_LOG_PATH="app/logs/${STAGE_LOWER}"

# Upload cloud-init log
if [[ -f "/var/log/cloud-init-${STAGE_LOWER}.log" ]]; then
    aws s3 cp "/var/log/cloud-init-${STAGE_LOWER}.log" "s3://$LOG_BUCKET_NAME/$STAGE_LOG_PATH/$INSTANCE_ID-cloud-init-$TIMESTAMP.log"
    echo "✅ Cloud-init log uploaded to s3://$LOG_BUCKET_NAME/$STAGE_LOG_PATH/"
else
    echo "⚠️ Cloud-init log not found for stage $STAGE"
fi

# Upload app log
if [[ -f "app.log" ]]; then
    aws s3 cp "app.log" "s3://$LOG_BUCKET_NAME/$APP_LOG_PATH/$INSTANCE_ID-app-$TIMESTAMP.log"
    echo "✅ App log uploaded to s3://$LOG_BUCKET_NAME/$APP_LOG_PATH/"
else
    echo "⚠️ App log not found for stage $STAGE"
fi

# Upload app configuration
aws s3 cp "/opt/app/config/app-config.json" "s3://$LOG_BUCKET_NAME/$STAGE_LOG_PATH/$INSTANCE_ID-config-$TIMESTAMP.json"
echo "✅ App config uploaded to s3://$LOG_BUCKET_NAME/$STAGE_LOG_PATH/"

echo "✅ All logs uploaded to S3 bucket: $LOG_BUCKET_NAME for stage: $STAGE"

# 🔟 Stage-specific shutdown behavior
if [[ "$SHUTDOWN_AFTER_MINUTES" -gt 0 ]]; then
    echo "⏱ Scheduling EC2 shutdown in $SHUTDOWN_AFTER_MINUTES minutes for stage: $STAGE..."
    sudo shutdown -h +$SHUTDOWN_AFTER_MINUTES
else
    echo "🔄 No auto-shutdown configured for stage: $STAGE (Production mode)"
fi

echo "🎉 Deployment completed successfully for stage: $STAGE!"
echo "📊 Application running on port $APP_PORT"
echo "📁 Logs available in S3: s3://$LOG_BUCKET_NAME/logs/$STAGE_LOWER/"
echo "🌍 Environment: $ENVIRONMENT"
