# Research 01.3: Multi-Hop Path Mapping Demo

## Overview

This sub-research provides a **working demonstration** of the multi-hop path mapping architecture using:
- **Infrastructure**: Terraform on AWS
- **Application**: Kotlin Spring Boot microservices
- **Container**: ECS Fargate

---

## Architecture

![Demo Architecture](./01.3-demo-architecture.png)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           DEMO ARCHITECTURE                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   Internet                                                                      │
│       │                                                                         │
│       ▼                                                                         │
│   ┌─────────────────────────────────────────────────────────────────────────┐  │
│   │  API Gateway (HTTP API)                                                  │  │
│   │  https://api.example.com                                                 │  │
│   │                                                                          │  │
│   │  Routes:                                                                 │  │
│   │  • GET  /accounts/{id}     → /account-svc/api/v1/accounts/{id}          │  │
│   │  • POST /accounts          → /account-svc/api/v1/accounts               │  │
│   │  • GET  /transfers/{id}    → /transfer-svc/api/v1/transfers/{id}        │  │
│   │  • POST /transfers         → /transfer-svc/api/v1/transfers             │  │
│   └───────────────────────────────────┬─────────────────────────────────────┘  │
│                                       │ VPC Link                               │
│                                       ▼                                        │
│   ┌─────────────────────────────────────────────────────────────────────────┐  │
│   │  VPC (Private)                                                           │  │
│   │  ┌───────────────────────────────────────────────────────────────────┐  │  │
│   │  │  ALB (Internal)                                                    │  │  │
│   │  │  • /account-svc/*  → Account Service Target Group                  │  │  │
│   │  │  • /transfer-svc/* → Transfer Service Target Group                 │  │  │
│   │  └───────────────────────────┬───────────────────────────────────────┘  │  │
│   │                              │                                           │  │
│   │              ┌───────────────┴───────────────┐                          │  │
│   │              ▼                               ▼                          │  │
│   │  ┌─────────────────────────┐   ┌─────────────────────────┐              │  │
│   │  │  ECS Fargate            │   │  ECS Fargate            │              │  │
│   │  │  Account Service        │   │  Transfer Service       │              │  │
│   │  │  (Kotlin Spring Boot)   │   │  (Kotlin Spring Boot)   │              │  │
│   │  │                         │   │                         │              │  │
│   │  │  /api/v1/accounts/*     │   │  /api/v1/transfers/*    │              │  │
│   │  └─────────────────────────┘   └─────────────────────────┘              │  │
│   └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Monorepo Structure

```
03-demo-multi-hop-terraform/
│
├── README.md                           # This file
├── 01.3-demo-architecture.drawio       # Architecture diagram source
├── 01.3-demo-architecture.png          # Architecture diagram export
├── Makefile                            # Build and deploy commands
├── .gitignore                          # Git ignore rules
│
├── infrastructure/                     # Terraform Infrastructure
│   ├── README.md                       # Infrastructure documentation
│   ├── versions.tf                     # Terraform and provider versions
│   ├── backend.tf                      # State backend configuration
│   ├── variables.tf                    # Root variables
│   ├── outputs.tf                      # Root outputs
│   ├── main.tf                         # Root module composition
│   │
│   ├── environments/                   # Environment-specific configs
│   │   ├── dev/
│   │   │   ├── terraform.tfvars
│   │   │   └── backend.hcl
│   │   └── prod/
│   │       ├── terraform.tfvars
│   │       └── backend.hcl
│   │
│   └── modules/                        # Reusable Terraform modules
│       ├── vpc/                        # VPC, Subnets, NAT Gateway
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       ├── api-gateway/                # HTTP API Gateway + VPC Link
│       │   ├── main.tf
│       │   ├── routes.tf
│       │   ├── integrations.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       ├── alb/                        # Application Load Balancer
│       │   ├── main.tf
│       │   ├── listener-rules.tf
│       │   ├── target-groups.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       ├── ecs-cluster/                # ECS Cluster
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       ├── ecs-service/                # ECS Service (reusable per service)
│       │   ├── main.tf
│       │   ├── task-definition.tf
│       │   ├── service.tf
│       │   ├── iam.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       ├── ecr/                        # ECR Repository
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       └── security-groups/            # Security Groups
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
├── applications/                       # Kotlin Spring Boot Applications
│   ├── README.md                       # Applications documentation
│   ├── settings.gradle.kts             # Gradle multi-project settings
│   ├── build.gradle.kts                # Root Gradle build
│   ├── gradle.properties               # Gradle properties
│   │
│   ├── buildSrc/                       # Shared build logic
│   │   ├── build.gradle.kts
│   │   └── src/main/kotlin/
│   │       └── conventions/
│   │           ├── kotlin-common.gradle.kts
│   │           └── spring-boot-app.gradle.kts
│   │
│   ├── shared/                         # Shared libraries
│   │   ├── common/                     # Common utilities
│   │   │   ├── build.gradle.kts
│   │   │   └── src/main/kotlin/
│   │   │       └── com/demo/common/
│   │   │           ├── exception/
│   │   │           ├── model/
│   │   │           └── util/
│   │   │
│   │   └── api-models/                 # Shared API models
│   │       ├── build.gradle.kts
│   │       └── src/main/kotlin/
│   │           └── com/demo/api/
│   │               ├── AccountDto.kt
│   │               └── TransferDto.kt
│   │
│   ├── account-service/                # Account Microservice
│   │   ├── build.gradle.kts
│   │   ├── Dockerfile
│   │   └── src/
│   │       ├── main/
│   │       │   ├── kotlin/
│   │       │   │   └── com/demo/account/
│   │       │   │       ├── AccountServiceApplication.kt
│   │       │   │       ├── config/
│   │       │   │       │   └── WebConfig.kt
│   │       │   │       ├── controller/
│   │       │   │       │   └── AccountController.kt
│   │       │   │       ├── service/
│   │       │   │       │   └── AccountService.kt
│   │       │   │       ├── repository/
│   │       │   │       │   └── AccountRepository.kt
│   │       │   │       └── model/
│   │       │   │           └── Account.kt
│   │       │   └── resources/
│   │       │       ├── application.yml
│   │       │       └── application-prod.yml
│   │       └── test/
│   │           └── kotlin/
│   │               └── com/demo/account/
│   │                   ├── controller/
│   │                   │   └── AccountControllerTest.kt
│   │                   └── service/
│   │                       └── AccountServiceTest.kt
│   │
│   └── transfer-service/               # Transfer Microservice
│       ├── build.gradle.kts
│       ├── Dockerfile
│       └── src/
│           ├── main/
│           │   ├── kotlin/
│           │   │   └── com/demo/transfer/
│           │   │       ├── TransferServiceApplication.kt
│           │   │       ├── config/
│           │   │       ├── controller/
│           │   │       │   └── TransferController.kt
│           │   │       ├── service/
│           │   │       │   └── TransferService.kt
│           │   │       └── model/
│           │   │           └── Transfer.kt
│           │   └── resources/
│           │       ├── application.yml
│           │       └── application-prod.yml
│           └── test/
│               └── kotlin/
│                   └── com/demo/transfer/
│
├── docker/                             # Docker configurations
│   ├── docker-compose.yml              # Local development
│   ├── docker-compose.override.yml     # Local overrides
│   └── nginx/                          # Local ALB simulation
│       └── nginx.conf
│
├── scripts/                            # Automation scripts
│   ├── build-all.sh                    # Build all applications
│   ├── push-images.sh                  # Push to ECR
│   ├── deploy-infra.sh                 # Deploy infrastructure
│   ├── deploy-apps.sh                  # Deploy applications
│   ├── destroy-all.sh                  # Tear down everything
│   └── local-dev.sh                    # Start local environment
│
├── docs/                               # Additional documentation
│   ├── SETUP.md                        # Setup instructions
│   ├── LOCAL-DEV.md                    # Local development guide
│   ├── DEPLOYMENT.md                   # Deployment guide
│   └── TROUBLESHOOTING.md              # Common issues
│
└── .github/                            # GitHub Actions (optional)
    └── workflows/
        ├── ci.yml                      # Build and test
        └── deploy.yml                  # Deploy to AWS
```

---

## Quick Start

### Prerequisites

- AWS CLI v2 configured
- Terraform >= 1.5
- JDK 17+
- Gradle 8+
- Docker & Docker Compose

### Local Development

```bash
# Start local environment (simulates ALB + services)
make local-up

# Run tests
make test

# Build all applications
make build
```

### Deploy to AWS

```bash
# Initialize Terraform
make infra-init ENV=dev

# Plan infrastructure changes
make infra-plan ENV=dev

# Apply infrastructure
make infra-apply ENV=dev

# Build and push Docker images
make docker-push ENV=dev

# Deploy ECS services
make deploy ENV=dev
```

---

## Path Mapping Configuration

### API Gateway Routes

| External Path | Internal Path | Service |
|--------------|---------------|---------|
| `GET /accounts/{id}` | `/account-svc/api/v1/accounts/{id}` | Account Service |
| `POST /accounts` | `/account-svc/api/v1/accounts` | Account Service |
| `GET /accounts/{id}/balance` | `/account-svc/api/v1/accounts/{id}/balance` | Account Service |
| `GET /transfers/{id}` | `/transfer-svc/api/v1/transfers/{id}` | Transfer Service |
| `POST /transfers` | `/transfer-svc/api/v1/transfers` | Transfer Service |

### ALB Listener Rules

| Priority | Path Pattern | Target Group | Path Rewrite |
|----------|-------------|--------------|--------------|
| 10 | `/account-svc/*` | account-tg | Strip `/account-svc` |
| 20 | `/transfer-svc/*` | transfer-tg | Strip `/transfer-svc` |
| 99 | `*` | 404 response | - |

### Application Endpoints (ECS)

| Service | Receives | Handles |
|---------|----------|---------|
| Account Service | `/api/v1/accounts/*` | Account CRUD |
| Transfer Service | `/api/v1/transfers/*` | Transfer operations |

---

## Key Files Reference

### Terraform

| File | Purpose |
|------|---------|
| `infrastructure/modules/api-gateway/routes.tf` | API Gateway route definitions |
| `infrastructure/modules/api-gateway/integrations.tf` | VPC Link integration with path rewrite |
| `infrastructure/modules/alb/listener-rules.tf` | ALB routing rules |

### Kotlin

| File | Purpose |
|------|---------|
| `applications/account-service/src/.../AccountController.kt` | REST endpoints |
| `applications/account-service/src/.../application.yml` | Server configuration |

---

## Related Documentation

- [01: Selective Path Mapping](../01-selective-path-mapping/README.md)
- [02: Multi-Hop Path Mapping](../02-multi-hop-path-mapping/README.md)
- [AWS HTTP API Documentation](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
