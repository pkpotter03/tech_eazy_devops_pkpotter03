#!/bin/bash

set -e

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
sudo mv apache-maven-${MAVEN_VERSION} /opt/maven
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
