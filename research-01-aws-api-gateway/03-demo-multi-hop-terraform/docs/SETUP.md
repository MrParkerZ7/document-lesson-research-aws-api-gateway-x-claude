# Setup Guide

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| AWS CLI | v2+ | AWS resource management |
| Terraform | >= 1.5 | Infrastructure as Code |
| JDK | 17+ | Kotlin/Spring Boot compilation |
| Gradle | 8+ | Build automation |
| Docker | Latest | Container runtime |
| Docker Compose | v2+ | Local development |

### AWS Setup

1. **Configure AWS CLI**
   ```bash
   aws configure
   # Enter your Access Key ID, Secret Access Key, and region
   ```

2. **Create S3 Bucket for Terraform State**
   ```bash
   aws s3 mb s3://your-terraform-state-bucket --region ap-southeast-1
   ```

3. **Create DynamoDB Table for State Locking**
   ```bash
   aws dynamodb create-table \
     --table-name terraform-state-lock \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST \
     --region ap-southeast-1
   ```

4. **Update Backend Configuration**

   Edit `infrastructure/environments/dev/backend.hcl`:
   ```hcl
   bucket         = "your-terraform-state-bucket"
   key            = "multi-hop-demo/dev/terraform.tfstate"
   region         = "ap-southeast-1"
   dynamodb_table = "terraform-state-lock"
   ```

---

## Local Development

### Option 1: Docker Compose (Recommended)

```bash
# Start all services
make local-up

# View logs
make local-logs

# Stop services
make local-down
```

**Test the endpoints:**
```bash
# Get account
curl http://localhost:8080/account-svc/api/v1/accounts/123

# Get balance
curl http://localhost:8080/account-svc/api/v1/accounts/123/balance

# Create account
curl -X POST http://localhost:8080/account-svc/api/v1/accounts \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User", "email": "test@example.com"}'

# Get transfer
curl http://localhost:8080/transfer-svc/api/v1/transfers/TRF001

# Create transfer
curl -X POST http://localhost:8080/transfer-svc/api/v1/transfers \
  -H "Content-Type: application/json" \
  -d '{"fromAccountId": "123", "toAccountId": "456", "amount": 50.00}'
```

### Option 2: Run Services Directly

```bash
# Build all applications
cd applications
./gradlew build

# Run Account Service (Terminal 1)
./gradlew :account-service:bootRun

# Run Transfer Service (Terminal 2)
./gradlew :transfer-service:bootRun
```

---

## AWS Deployment

### Step 1: Initialize Terraform

```bash
make infra-init ENV=dev
```

### Step 2: Review Changes

```bash
make infra-plan ENV=dev
```

### Step 3: Apply Infrastructure

```bash
make infra-apply ENV=dev
```

### Step 4: Build and Push Docker Images

```bash
make docker-build
make docker-push ENV=dev
```

### Step 5: Verify Deployment

```bash
# Get API Gateway URL
make infra-output

# Test endpoints
API_URL=$(terraform -chdir=infrastructure output -raw api_gateway_url)
curl $API_URL/accounts/123
```

---

## Cleanup

### Remove AWS Resources

```bash
make destroy ENV=dev
```

### Remove Local Resources

```bash
make local-down
docker system prune -f
```

---

## Troubleshooting

### Common Issues

**1. Terraform state lock error**
```bash
terraform force-unlock <LOCK_ID>
```

**2. ECR login fails**
```bash
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-southeast-1.amazonaws.com
```

**3. ECS service not starting**
- Check CloudWatch logs: `/ecs/multi-hop-demo-dev/<service-name>`
- Verify security group rules
- Check target group health checks

**4. API Gateway 404 errors**
- Verify route configuration in API Gateway console
- Check VPC Link connectivity
- Verify ALB listener rules
