#!/bin/bash
set -e

# 1️⃣ Load config
STAGE=$1
CONFIG_FILE="./${STAGE,,}_config"
source "$CONFIG_FILE"

# 2️⃣ Install system dependencies
sudo apt update -y
sudo apt install -y curl unzip git openjdk-${JAVA_VERSION}-jdk
echo "✅ Java version: $(java -version 2>&1 | head -n 1)"

# 3️⃣ Install Maven
wget https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip
unzip -o apache-maven-${MAVEN_VERSION}-bin.zip
sudo mv apache-maven-${MAVEN_VERSION} /opt/maven/
sudo ln -sf /opt/maven/bin/mvn /usr/bin/mvn
echo "✅ Maven version: $(mvn -v | head -n 1)"

# 4️⃣ Install AWS CLI (needed for log upload)
if ! command -v aws &> /dev/null; then
    echo "📦 Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -o awscliv2.zip
    sudo ./aws/install
    export PATH=$PATH:/usr/local/bin
    echo "✅ AWS CLI installed: $(aws --version)"
else
    echo "✅ AWS CLI already installed: $(aws --version)"
fi

# 5️⃣ Clone & build Spring Boot app
git clone "$REPO_URL" || true
cd $(basename "$REPO_URL" .git)
mvn clean package

# 6️⃣ Run the app
nohup java -jar target/*.jar --server.port=$APP_PORT > app.log 2>&1 &
echo "✅ App is running on port $APP_PORT"

# 7️⃣ Test app
sleep 10
if curl -f "http://$(curl -s http://checkip.amazonaws.com)/hello"; then
    echo "✅ App is reachable."
else
    echo "❌ App is not reachable. Exiting."
    exit 1
fi

# 8️⃣ Upload logs (Terraform already created the bucket)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
aws s3 cp /var/log/cloud-init.log s3://$LOG_BUCKET_NAME/logs/$INSTANCE_ID-cloud-init-$TIMESTAMP.log
aws s3 cp app.log s3://$LOG_BUCKET_NAME/app/logs/$INSTANCE_ID-app-$TIMESTAMP.log
echo "✅ Logs uploaded to S3 bucket: $LOG_BUCKET_NAME"

# 9️⃣ Shutdown after defined minutes
sudo shutdown -h +$SHUTDOWN_AFTER_MINUTES
echo "✅ System will shut down in $SHUTDOWN_AFTER_MINUTES minutes."
