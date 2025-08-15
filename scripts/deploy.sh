#!/bin/bash
set -e

# 1️⃣ Load config
STAGE=$1
CONFIG_FILE="./${STAGE,,}_config"
source "$CONFIG_FILE"

# 2️⃣ Install system dependencies
sudo apt update -y
sudo apt install -y curl unzip git openjdk-${JAVA_VERSION}-jdk

# 3️⃣ Install Maven
wget https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip
unzip apache-maven-${MAVEN_VERSION}-bin.zip
sudo mv apache-maven-${MAVEN_VERSION} /opt/maven/
sudo ln -sf /opt/maven/bin/mvn /usr/bin/mvn

# 4️⃣ Clone & build Spring Boot app
git clone "$REPO_URL" || true
cd $(basename "$REPO_URL" .git)
mvn clean package

# 5️⃣ Run the app
nohup java -jar target/*.jar --server.port=$APP_PORT > app.log 2>&1 &

# 6️⃣ Test app
sleep 10
curl "http://$(curl -s http://checkip.amazonaws.com)/hello"

# 7️⃣ Upload logs (bucket is already created by Terraform)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
aws s3 cp /var/log/cloud-init.log s3://$LOG_BUCKET_NAME/logs/$INSTANCE_ID-cloud-init-$TIMESTAMP.log
aws s3 cp app.log s3://$LOG_BUCKET_NAME/app/logs/$INSTANCE_ID-app-$TIMESTAMP.log

# 8️⃣ Shutdown after defined minutes
sudo shutdown -h +$SHUTDOWN_AFTER_MINUTES
