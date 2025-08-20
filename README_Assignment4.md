# DevOps Assignment 4 - Parameterized Multi-Stage Deployment

This repository demonstrates **advanced infrastructure provisioning and automated deployment** with support for multiple stages (dev, qa, prod), private/public GitHub repository handling, and stage-based logging.

---

## 🎯 **Assignment 4 Features**

### **✅ Multi-Stage Deployment Support**
- **Three stages**: `dev`, `qa`, `prod`
- **Stage-specific configurations**: Instance types, ports, timeouts
- **Parameterized Terraform**: Dynamic resource provisioning per stage

### **✅ Private/Public GitHub Config Handling**
- **Public repos**: Dev and QA stages (no authentication required)
- **Private repos**: Production stage (GitHub PAT authentication)
- **Secure token handling**: GitHub tokens passed via GitHub Actions secrets

### **✅ Stage-Based S3 Log Upload**
- **Organized logging**: `s3://bucket/logs/dev/`, `s3://bucket/logs/qa/`, `s3://bucket/logs/prod/`
- **Comprehensive logs**: Cloud-init, application, and configuration files
- **Lifecycle management**: Automatic cleanup after 7 days

### **✅ Enhanced Health Checks**
- **Port-specific monitoring**: Health checks on configured ports (default: 8080)
- **Stage-aware testing**: Different health check strategies per environment
- **Extended timeout**: 3-minute health check window

### **✅ Comprehensive Resource Cleanup**
- **Multi-stage destruction**: Destroy specific stages or all stages at once
- **Duplicate name prevention**: Ensures clean removal of all AWS resources
- **Fallback cleanup**: Manual cleanup options if Terraform destroy fails

---

## 📁 **Enhanced Project Structure**

```
.
├── README_Assignment4.md          # This file
├── README.md                      # Original project documentation
├── scripts/
│   ├── deploy.sh                  # Enhanced multi-stage deployment script
│   ├── cleanup.sh                 # Manual AWS resource cleanup script
│   ├── Dev_config                 # Development stage configuration
│   ├── QA_config                  # QA stage configuration  
│   ├── Prod_config                # Production stage configuration
│   ├── dev.json                   # Dev stage application config
│   ├── qa.json                    # QA stage application config
│   ├── prod.json                  # Production stage application config
│   └── env.template               # Environment variables template
├── infra/terraform/
│   ├── main.tf                    # Enhanced Terraform with multi-stage support
│   ├── variables.tf               # Multi-stage variables and validation
│   ├── outputs.tf                 # Terraform outputs
│   └── provider.tf                # AWS provider configuration
└── .github/workflows/
    ├── deploy.yml                 # Enhanced multi-stage CI/CD pipeline
    └── destroy.yml                # Enhanced multi-stage destruction workflow
```

---

## 🚀 **Deployment Strategies**

### **1. Tag-Based Deployment**
```bash
# Deploy to Development
git tag deploy-dev && git push origin deploy-dev

# Deploy to QA
git tag deploy-qa && git push origin deploy-qa

# Deploy to Production
git tag deploy-prod && git push origin deploy-prod
```

### **2. Manual Workflow Dispatch**
- Go to GitHub Actions → Deploy workflow
- Select stage: Dev/QA/Prod
- Click "Run workflow"

### **3. Push to Main Branch**
- Automatically deploys to Development stage

---

## 🗑️ **Resource Cleanup & Destruction**

### **Enhanced Destroy Workflow**
The `destroy.yml` workflow has been enhanced to prevent duplicate name errors:

#### **Single Stage Destruction**
- **Select specific stage**: Dev, QA, or Prod
- **Stage-aware cleanup**: Uses stage-specific configurations
- **Proper variable passing**: Ensures all resources are identified

#### **Complete Environment Destruction**
- **Destroy all stages**: Option to clean up entire environment
- **Sequential cleanup**: Processes stages in order (dev → qa → prod)
- **Comprehensive removal**: All AWS resources are properly identified and removed

#### **Fallback Cleanup**
- **IAM resource cleanup**: If Terraform destroy fails, manually removes IAM resources
- **Resource verification**: Shows remaining resources after cleanup
- **Error handling**: Graceful cleanup even if some resources fail

### **Manual Cleanup Script**
For cases where GitHub Actions cleanup isn't sufficient:

```bash
# Run the cleanup script (Linux/Mac)
./scripts/cleanup.sh

# On Windows, use Git Bash or WSL
bash scripts/cleanup.sh
```

#### **What the Cleanup Script Does**
- **EC2 Instances**: Finds and terminates project instances
- **Security Groups**: Removes stage-specific security groups
- **IAM Resources**: Cleans up roles, policies, and instance profiles
- **S3 Buckets**: Empties and deletes log buckets
- **Interactive Confirmation**: Asks before deleting each resource

#### **When to Use Manual Cleanup**
- **Terraform state corruption**: If Terraform can't track resources
- **Partial failures**: When some resources weren't created by Terraform
- **Duplicate name errors**: To ensure clean slate for redeployment
- **Testing scenarios**: When you need to verify cleanup manually

---

## ⚙️ **Stage-Specific Configurations**

### **Development Stage (`dev`)**
- **Instance Type**: `t3.micro`
- **Port**: `8080`
- **Repository**: Public GitHub repo
- **Auto-shutdown**: 60 minutes
- **Log Level**: DEBUG
- **Environment**: Development

### **QA Stage (`qa`)**
- **Instance Type**: `t3.small`
- **Port**: `8080`
- **Repository**: Public GitHub repo
- **Auto-shutdown**: 120 minutes
- **Log Level**: INFO
- **Environment**: Testing

### **Production Stage (`prod`)**
- **Instance Type**: `t3.medium`
- **Port**: `8080`
- **Repository**: Private GitHub repo
- **Auto-shutdown**: Never (0 minutes)
- **Log Level**: WARN
- **Environment**: Production

---

## 🔐 **GitHub Repository Access Strategy**

### **Public Repositories (Dev/QA)**
- **Access**: No authentication required
- **Use Case**: Development and testing environments
- **Security**: Lower security requirements

### **Private Repositories (Production)**
- **Access**: GitHub Personal Access Token (PAT)
- **Authentication**: Token passed via GitHub Actions secrets
- **Security**: Production-grade security
- **Token Setup**: 
  1. Generate PAT in GitHub Settings
  2. Add to repository secrets as `GITHUB_TOKEN`
  3. Token automatically passed to EC2 during deployment

---

## 📊 **S3 Logging Structure**

```
s3://your-bucket/
├── logs/
│   ├── dev/
│   │   ├── i-1234567890abcdef0-cloud-init-2024-01-15_10-30-00.log
│   │   ├── i-1234567890abcdef0-config-2024-01-15_10-30-00.json
│   │   └── ...
│   ├── qa/
│   │   ├── i-0987654321fedcba0-cloud-init-2024-01-15_11-00-00.log
│   │   ├── i-0987654321fedcba0-config-2024-01-15_11-00-00.json
│   │   └── ...
│   └── prod/
│       ├── i-abcdef1234567890-cloud-init-2024-01-15_12-00-00.log
│       ├── i-abcdef1234567890-config-2024-01-15_12-00-00.json
│       └── ...
└── app/logs/
    ├── dev/
    │   ├── i-1234567890abcdef0-app-2024-01-15_10-30-00.log
    │   └── ...
    ├── qa/
    │   ├── i-0987654321fedcba0-app-2024-01-15_11-00-00.log
    │   └── ...
    └── prod/
        ├── i-abcdef1234567890-app-2024-01-15_12-00-00.log
        └── ...
```

---

## 🔧 **Required GitHub Secrets**

```yaml
# AWS Configuration
AWS_ACCESS_KEY_ID: "your-aws-access-key"
AWS_SECRET_ACCESS_KEY: "your-aws-secret-key"
AWS_REGION: "ap-south-1"

# SSH Access
SSH_PRIVATE_KEY: "your-ec2-private-key"

# Terraform Variables
TF_VAR_key_name: "your-ec2-key-pair-name"
TF_VAR_log_bucket_name: "your-unique-s3-bucket-name"

# GitHub Access (for private repos)
GITHUB_TOKEN: "your-github-personal-access-token"
```

---

## 🧪 **Testing Your Deployment**

### **1. Test Development Stage**
```bash
# Create and push tag
git tag deploy-dev
git push origin deploy-dev

# Monitor GitHub Actions
# Check S3 logs: s3://bucket/logs/dev/
# Verify app on port 8080
```

### **2. Test QA Stage**
```bash
# Create and push tag
git tag deploy-qa
git push origin deploy-qa

# Monitor deployment
# Check S3 logs: s3://bucket/logs/qa/
```

### **3. Test Production Stage**
```bash
# Create and push tag
git tag deploy-prod
git push origin deploy-prod

# Verify private repo access
# Check production logs: s3://bucket/logs/prod/
```

---

## 🗑️ **Testing Cleanup & Destruction**

### **1. Test Single Stage Destruction**
- Go to GitHub Actions → "Multi-Stage Terraform Destroy"
- Select stage: Dev/QA/Prod
- Click "Run workflow"
- Monitor cleanup process

### **2. Test Complete Environment Destruction**
- Go to GitHub Actions → "Multi-Stage Terraform Destroy"
- Check "Destroy all stages" checkbox
- Click "Run workflow"
- Verify all resources are removed

### **3. Test Manual Cleanup (if needed)**
```bash
# Run cleanup script
bash scripts/cleanup.sh

# Follow interactive prompts
# Verify all resources are cleaned up
```

---

## 🔍 **Health Check Endpoints**

### **Application Health**
- **Endpoint**: `/hello`
- **Expected Response**: "Hello from Spring MVC!"
- **Port**: Configurable per stage (default: 8080)
- **Timeout**: 3 minutes for health check

### **Health Check Process**
1. **Deployment**: App starts with stage-specific config
2. **Polling**: GitHub Actions polls `/hello` endpoint
3. **Verification**: Confirms app is responding correctly
4. **Logging**: Health status logged to S3

---

## 🚨 **Troubleshooting**

### **Common Issues**

#### **1. Private Repository Access Failed**
```bash
# Check GitHub token in secrets
# Verify token has repo access permissions
# Check token expiration
```

#### **2. Health Check Failed**
```bash
# Verify app is running on correct port
# Check application logs in S3
# Verify security group allows port access
```

#### **3. S3 Upload Failed**
```bash
# Check IAM role permissions
# Verify S3 bucket exists
# Check AWS credentials
```

#### **4. Duplicate Name Errors on Redeployment**
```bash
# Run the destroy workflow first
# Use "Destroy all stages" option
# Run manual cleanup script if needed
# Verify all resources are removed before redeploying
```

### **Debug Commands**
```bash
# Check app status
sudo systemctl status your-app

# View application logs
tail -f /home/ubuntu/app.log

# Check port usage
sudo netstat -tlnp | grep 8080

# Verify S3 access
aws s3 ls s3://your-bucket/logs/

# Check for remaining AWS resources
aws ec2 describe-instances --filters "Name=tag:Project,Values=DevOps-Assignment-3"
aws iam list-roles --query "Roles[?contains(RoleName, 'assignment3-')]"
```

---

## 📈 **Monitoring and Observability**

### **S3 Log Analysis**
- **Cloud-init logs**: Infrastructure setup details
- **Application logs**: Runtime behavior and errors
- **Configuration files**: Stage-specific settings
- **Timestamps**: Deployment tracking and auditing

### **Health Metrics**
- **Response time**: Application performance
- **Uptime**: Service availability
- **Error rates**: Application health
- **Resource usage**: Infrastructure monitoring

### **Cleanup Verification**
- **Resource inventory**: Before and after cleanup
- **IAM resource tracking**: Roles, policies, and profiles
- **S3 bucket status**: Empty vs. populated buckets
- **EC2 instance states**: Running vs. terminated

---

## 🔮 **Future Enhancements**

### **Potential Improvements**
1. **Blue-Green Deployment**: Zero-downtime deployments
2. **Rollback Mechanism**: Automatic rollback on failure
3. **Advanced Monitoring**: CloudWatch metrics and alarms
4. **Load Balancing**: Multi-instance deployments
5. **Database Integration**: Stage-specific database provisioning
6. **SSL/TLS**: HTTPS support for production
7. **CDN Integration**: Content delivery optimization
8. **Automated Testing**: Integration tests for cleanup processes
9. **Resource Tagging**: Enhanced resource identification and cleanup

---

## 📚 **References**

- [Terraform Multi-Stage Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/part1.html)
- [GitHub Actions Secrets Management](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [AWS S3 Lifecycle Policies](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
- [Spring Boot Configuration](https://docs.spring.io/spring-boot/docs/current/reference/html/spring-boot-features.html#boot-features-external-config)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Terraform State Management](https://www.terraform.io/docs/language/state/index.html)

---

## 🎉 **Conclusion**

This implementation successfully demonstrates:
- **Multi-stage deployment** with environment-specific configurations
- **Secure handling** of private GitHub repositories
- **Organized logging** with stage-based S3 folder structure
- **Robust health monitoring** with configurable ports
- **Infrastructure as Code** best practices with Terraform
- **CI/CD automation** with GitHub Actions
- **Comprehensive resource cleanup** preventing duplicate name errors
- **Fallback cleanup mechanisms** ensuring reliable resource management

The solution provides a **production-ready foundation** for multi-environment deployments with proper security, monitoring, logging, and cleanup capabilities. The enhanced destroy workflow ensures that redeployments won't encounter duplicate name errors, making the system reliable for continuous development and testing cycles. 