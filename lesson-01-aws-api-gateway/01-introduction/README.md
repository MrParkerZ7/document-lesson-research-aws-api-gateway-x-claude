# 01. Introduction to AWS API Gateway

## Overview

AWS API Gateway is a fully managed service that makes it easy for developers to create, publish, maintain, monitor, and secure APIs at any scale. It handles all the tasks involved in accepting and processing up to hundreds of thousands of concurrent API calls, including traffic management, CORS support, authorization and access control, throttling, monitoring, and API version management.

## Learning Objectives

- Understand what an API Gateway is and why it's needed
- Learn the core components of AWS API Gateway
- Identify common use cases and architectural patterns
- Understand the request/response lifecycle

## What is an API Gateway?

An API Gateway is an API management tool that sits between a client and a collection of backend services. It acts as a reverse proxy to accept all API calls, aggregate the various services required to fulfill them, and return the appropriate result.

### Without API Gateway

```
┌──────────┐     ┌──────────────┐
│  Client  │────▶│  Service A   │
└──────────┘     └──────────────┘

┌──────────┐     ┌──────────────┐
│  Client  │────▶│  Service B   │
└──────────┘     └──────────────┘

┌──────────┐     ┌──────────────┐
│  Client  │────▶│  Service C   │
└──────────┘     └──────────────┘

Problems:
- Multiple endpoints to manage
- Security implemented per service
- No centralized monitoring
- Direct exposure of backend services
```

### With API Gateway

```
┌──────────┐     ┌─────────────────┐     ┌──────────────┐
│          │     │                 │────▶│  Service A   │
│  Client  │────▶│   API Gateway   │────▶│  Service B   │
│          │     │                 │────▶│  Service C   │
└──────────┘     └─────────────────┘     └──────────────┘

Benefits:
- Single entry point
- Centralized authentication
- Unified monitoring & logging
- Request transformation
- Rate limiting & throttling
```

## Core Components of AWS API Gateway

### 1. API

The top-level container that holds all resources, methods, and configurations.

```
API (e.g., "Banking API")
├── Resources (URL paths)
│   ├── /accounts
│   ├── /accounts/{id}
│   ├── /transactions
│   └── /payments
├── Methods (HTTP verbs per resource)
│   ├── GET /accounts
│   ├── POST /accounts
│   ├── GET /accounts/{id}
│   └── POST /payments
└── Stages (deployment environments)
    ├── dev
    ├── staging
    └── prod
```

### 2. Resources

Resources are the URL paths that make up your API. They form a hierarchical tree structure.

```
/                           # Root resource
├── /customers              # Collection resource
│   └── /{customerId}       # Item resource with path parameter
│       ├── /accounts       # Nested collection
│       └── /profile        # Nested singleton
├── /accounts
│   └── /{accountId}
│       └── /transactions
└── /health                 # Utility endpoint
```

### 3. Methods

Methods represent the HTTP verbs (GET, POST, PUT, DELETE, etc.) that can be called on each resource.

| Method | Resource | Description |
|--------|----------|-------------|
| GET | /customers | List all customers |
| POST | /customers | Create a new customer |
| GET | /customers/{id} | Get customer by ID |
| PUT | /customers/{id} | Update customer |
| DELETE | /customers/{id} | Delete customer |

### 4. Integrations

Integrations define where requests should be forwarded after processing.

| Integration Type | Description | Use Case |
|-----------------|-------------|----------|
| Lambda Function | Invoke AWS Lambda | Serverless compute |
| HTTP | Forward to HTTP endpoint | Existing APIs, microservices |
| AWS Service | Direct AWS service calls | DynamoDB, S3, SQS, Step Functions |
| VPC Link | Connect to private resources | ECS, EKS, EC2 in VPC |
| Mock | Return mock response | Testing, prototyping |

### 5. Stages

Stages are named references to a deployment of your API. Each stage has its own configuration.

```
┌─────────────────────────────────────────────────────┐
│                    Banking API                       │
├─────────────────────────────────────────────────────┤
│  Stage: dev                                          │
│  URL: https://abc123.execute-api.region.amazonaws.com/dev
│  Settings: Logging=DEBUG, Throttle=100 req/s        │
├─────────────────────────────────────────────────────┤
│  Stage: staging                                      │
│  URL: https://abc123.execute-api.region.amazonaws.com/staging
│  Settings: Logging=INFO, Throttle=500 req/s         │
├─────────────────────────────────────────────────────┤
│  Stage: prod                                         │
│  URL: https://abc123.execute-api.region.amazonaws.com/prod
│  Settings: Logging=ERROR, Throttle=10000 req/s      │
│  Custom Domain: api.mybank.com                       │
└─────────────────────────────────────────────────────┘
```

## Request/Response Lifecycle

```
┌────────────────────────────────────────────────────────────────────────┐
│                        REQUEST FLOW                                     │
└────────────────────────────────────────────────────────────────────────┘

  Client                    API Gateway                         Backend
    │                           │                                   │
    │  1. HTTP Request          │                                   │
    │──────────────────────────▶│                                   │
    │                           │                                   │
    │                    2. Method Request                          │
    │                    ┌──────────────┐                           │
    │                    │ • Validate   │                           │
    │                    │ • Authorize  │                           │
    │                    │ • Transform  │                           │
    │                    └──────────────┘                           │
    │                           │                                   │
    │                    3. Integration Request                     │
    │                           │──────────────────────────────────▶│
    │                           │                                   │
    │                    4. Integration Response                    │
    │                           │◀──────────────────────────────────│
    │                           │                                   │
    │                    5. Method Response                         │
    │                    ┌──────────────┐                           │
    │                    │ • Transform  │                           │
    │                    │ • Map status │                           │
    │                    │ • Add headers│                           │
    │                    └──────────────┘                           │
    │                           │                                   │
    │  6. HTTP Response         │                                   │
    │◀──────────────────────────│                                   │
    │                           │                                   │
```

### Detailed Lifecycle Stages

#### 1. Method Request
- **Authorization**: Check if request is allowed (IAM, Cognito, Lambda Authorizer)
- **Validation**: Validate request parameters, headers, body against model
- **API Key**: Check API key if required

#### 2. Integration Request
- **Request Transformation**: Map request to backend format using VTL templates
- **Parameter Mapping**: Pass path parameters, query strings, headers
- **Request Body**: Transform JSON/XML body as needed

#### 3. Integration Response
- **Response Mapping**: Map backend response based on status code patterns
- **Error Handling**: Handle backend errors and timeouts

#### 4. Method Response
- **Status Code Mapping**: Map to appropriate HTTP status codes
- **Response Transformation**: Transform response body
- **Headers**: Add or modify response headers

## Common Use Cases

### 1. Serverless Backend for Web/Mobile Apps

```
Mobile App ──▶ API Gateway ──▶ Lambda ──▶ DynamoDB
                    │
                    └──▶ Cognito (Auth)
```

### 2. Microservices Facade

```
                         ┌──▶ User Service (ECS)
                         │
Client ──▶ API Gateway ──┼──▶ Order Service (Lambda)
                         │
                         └──▶ Payment Service (EC2)
```

### 3. Legacy System Modernization

```
New Clients ──▶ API Gateway ──▶ VPC Link ──▶ Legacy System (On-prem)
                    │
                    └──▶ Lambda (Transform SOAP to REST)
```

### 4. Third-Party API Integration

```
Partner ──▶ API Gateway ──▶ Lambda ──▶ Internal Systems
                │
                ├── API Key validation
                ├── Rate limiting (100 req/day)
                └── Usage tracking
```

### 5. Real-Time Applications (WebSocket)

```
Browser ◀──WebSocket──▶ API Gateway ──▶ Lambda ──▶ DynamoDB
                            │
                            └──▶ Connection Management
```

## Banking Domain Example

Here's how API Gateway might be used in a banking context:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        BANKING API GATEWAY                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  /v1/customers                                                          │
│  ├── POST   - Onboard new customer (KYC integration)                    │
│  ├── GET    - List customers (with pagination)                          │
│  └── /{cif}                                                             │
│      ├── GET    - Get customer profile                                  │
│      ├── PUT    - Update customer info                                  │
│      └── /accounts                                                      │
│          └── GET - List customer accounts                               │
│                                                                          │
│  /v1/accounts                                                           │
│  └── /{accountId}                                                       │
│      ├── GET    - Get account details                                   │
│      ├── /balance                                                       │
│      │   └── GET - Get current balance (real-time)                      │
│      └── /transactions                                                  │
│          ├── GET  - List transactions (with date range)                 │
│          └── POST - Create transaction                                  │
│                                                                          │
│  /v1/payments                                                           │
│  ├── POST   - Initiate payment (RTGS, ACH, SWIFT)                       │
│  └── /{paymentId}                                                       │
│      ├── GET    - Get payment status                                    │
│      └── DELETE - Cancel payment (if pending)                           │
│                                                                          │
│  /v1/loans                                                              │
│  ├── POST   - Submit loan application                                   │
│  └── /{loanId}                                                          │
│      ├── GET    - Get loan details                                      │
│      └── /schedule                                                      │
│          └── GET - Get repayment schedule                               │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

Security Features Applied:
• OAuth 2.0 / Cognito for customer authentication
• mTLS for partner integrations (SWIFT, payment networks)
• WAF rules for OWASP protection
• Request validation (IBAN format, amount limits)
• PCI-DSS compliant logging (masked card numbers)
```

## Key Takeaways

1. **API Gateway is a central entry point** - Simplifies client interactions with multiple backend services
2. **Decouples clients from backends** - Backend changes don't affect client integrations
3. **Built-in cross-cutting concerns** - Authentication, monitoring, rate limiting out of the box
4. **Flexible integration options** - Works with Lambda, HTTP, AWS services, and private resources
5. **Stage management** - Easy promotion from dev to staging to production

## Further Reading

- [Getting Started with API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/getting-started.html)
- [API Gateway Concepts](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-basic-concept.html)
- [REST API vs HTTP API](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html)
