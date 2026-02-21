# Research 01.2: Multi-Hop Path Mapping

## Research Question

### Q2: How do path prefixes work across multiple routing layers?

**Scenario:**
```
Transit Gateway → API Gateway → ALB → ECS Fargate
```

Each layer has its own domain and path mapping:
- Transit Gateway: `tgw.example.com/app-gateway-name/*`
- API Gateway: `apigw.example.com/app-alb-name/*`
- ALB: `alb.internal.com/app-name/*`
- ECS Fargate: (no domain, receives final path)

**Problem:** Path prefixes accumulate or conflict across layers.

---

## Architecture Overview

![Multi-Hop Path Mapping](./01.2-multi-hop-path-mapping.png)

---

## The Path Accumulation Problem

### What Happens Without Path Stripping?

When a client calls:
```
https://tgw.example.com/payment-gateway/accounts/123
```

**Without path management**, each layer appends:

| Layer | Receives | Forwards |
|-------|----------|----------|
| Transit GW | `/payment-gateway/accounts/123` | `/payment-gateway/accounts/123` |
| API Gateway | `/payment-gateway/accounts/123` | `/payment-alb/payment-gateway/accounts/123` ❌ |
| ALB | `/payment-alb/payment-gateway/accounts/123` | `/payment-svc/payment-alb/payment-gateway/accounts/123` ❌ |
| ECS | `/payment-svc/payment-alb/payment-gateway/accounts/123` | **Path explosion!** ❌ |

### The Core Conflict

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         THE MAPPING CONFLICT                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   INFRA TEAM VIEW:                    DEV TEAM VIEW:                        │
│   ─────────────────                   ──────────────                        │
│   "Each layer should prefix          "We just want clean paths             │
│    with its app name for              at the application level:            │
│    routing and identification"        /accounts/123"                        │
│                                                                             │
│   /payment-gateway/*                  Expected by ECS:                      │
│       └── /payment-alb/*              GET /accounts/123                     │
│              └── /payment-svc/*       POST /transfers                       │
│                     └── ???           DELETE /accounts/123/cards/456        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Solution Approaches

### Approach 1: Strip at Each Layer (Recommended)

Each layer removes its prefix before forwarding.

```
Client Request:
  https://tgw.example.com/payment-gateway/accounts/123

┌─────────────────────────────────────────────────────────────────────────────┐
│ TRANSIT GATEWAY (tgw.example.com)                                           │
│                                                                             │
│   Route: /payment-gateway/* → API Gateway                                   │
│   Action: STRIP PREFIX /payment-gateway                                     │
│                                                                             │
│   IN:  /payment-gateway/accounts/123                                        │
│   OUT: /accounts/123                                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ API GATEWAY (apigw.example.com)                                             │
│                                                                             │
│   Route: /accounts/{id} → ALB Integration                                   │
│   Path Rewrite: overwrite:path = /app-name/api/v1/accounts/${request.path.id} │
│                                                                             │
│   IN:  /accounts/123                                                        │
│   OUT: /app-name/api/v1/accounts/123                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ ALB (alb.internal.com)                                                      │
│                                                                             │
│   Listener Rule: /app-name/* → Target Group (ECS)                           │
│   Path Pattern: /app-name/api/v1/*                                          │
│                                                                             │
│   IN:  /app-name/api/v1/accounts/123                                        │
│   OUT: /api/v1/accounts/123  (ALB can strip prefix with rule rewrite)       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ ECS FARGATE                                                                 │
│                                                                             │
│   Application receives clean path:                                          │
│   GET /api/v1/accounts/123                                                  │
│                                                                             │
│   ✓ Developer-friendly                                                      │
│   ✓ No path prefix logic in application code                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Approach 2: Passthrough with Full Path (Alternative)

If the application handles full paths:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Each layer passes through without modification                              │
│                                                                             │
│   Transit GW: /payment-gateway/accounts/123 → passes as-is                  │
│   API Gateway: Uses {proxy+} to forward entire path                         │
│   ALB: Routes based on /payment-gateway/* pattern                           │
│   ECS: Application handles /payment-gateway/accounts/123                    │
│                                                                             │
│   ⚠ Requires application to understand full routing path                    │
│   ⚠ Tight coupling between infrastructure and application                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Detailed Path Flow Diagram

### Scenario: Payment Service with Multiple Endpoints

```
EXTERNAL URL STRUCTURE:
═══════════════════════════════════════════════════════════════════════════════

tgw.example.com
    │
    ├── /payment-gateway          ──→ Payment API Gateway
    │       ├── /accounts/*       ──→ Account Service (ECS)
    │       ├── /transfers/*      ──→ Transfer Service (ECS)
    │       └── /cards/*          ──→ Card Service (ECS)
    │
    ├── /customer-gateway         ──→ Customer API Gateway
    │       └── /profiles/*       ──→ Profile Service (ECS)
    │
    └── /loan-gateway             ──→ Loan API Gateway
            └── /applications/*   ──→ Loan Service (ECS)


INTERNAL PATH TRANSFORMATION:
═══════════════════════════════════════════════════════════════════════════════

Layer 1: Transit Gateway
┌─────────────────────────────────────────────────────────────────────────────┐
│  /payment-gateway/accounts/123                                              │
│         │                                                                   │
│         └──→ Route to: payment-apigw.internal.com                           │
│              Forward:  /accounts/123  (prefix stripped)                     │
└─────────────────────────────────────────────────────────────────────────────┘

Layer 2: API Gateway (payment-apigw.internal.com)
┌─────────────────────────────────────────────────────────────────────────────┐
│  Route Configuration:                                                       │
│                                                                             │
│  GET /accounts/{accountId}                                                  │
│      Integration: HTTP_PROXY → ALB                                          │
│      overwrite:path: /account-svc/api/v1/accounts/${request.path.accountId} │
│                                                                             │
│  IN:  /accounts/123                                                         │
│  OUT: /account-svc/api/v1/accounts/123                                      │
└─────────────────────────────────────────────────────────────────────────────┘

Layer 3: ALB (alb.internal.com)
┌─────────────────────────────────────────────────────────────────────────────┐
│  Listener Rules:                                                            │
│                                                                             │
│  Priority 1: Path /account-svc/*  → account-tg (ECS Account Service)        │
│  Priority 2: Path /transfer-svc/* → transfer-tg (ECS Transfer Service)      │
│  Priority 3: Path /card-svc/*     → card-tg (ECS Card Service)              │
│  Default:    → 404                                                          │
│                                                                             │
│  Path Handling Options:                                                     │
│  ├── Option A: Forward /account-svc/api/v1/accounts/123 (app handles)       │
│  └── Option B: Rewrite to /api/v1/accounts/123 (ALB strips prefix)          │
└─────────────────────────────────────────────────────────────────────────────┘

Layer 4: ECS Fargate (Account Service)
┌─────────────────────────────────────────────────────────────────────────────┐
│  Application Route Handler:                                                 │
│                                                                             │
│  // Option A: Handle with prefix                                            │
│  @GetMapping("/account-svc/api/v1/accounts/{id}")                           │
│                                                                             │
│  // Option B: Clean path (recommended)                                      │
│  @GetMapping("/api/v1/accounts/{id}")                                       │
│                                                                             │
│  Receives: GET /api/v1/accounts/123                                         │
│  Response: { "accountId": "123", "balance": 1000.00 }                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Configuration Examples

### Transit Gateway Route Configuration

```yaml
# AWS Transit Gateway Route Table
Routes:
  - DestinationCidrBlock: "10.0.0.0/16"  # VPC CIDR
    Attachment: payment-vpc-attachment

# Application-level routing typically handled by:
# - Route 53 + CloudFront, or
# - Another ALB/NLB in front
```

### API Gateway Path Rewriting

```yaml
# API Gateway HTTP API - OpenAPI Spec
paths:
  /accounts/{accountId}:
    get:
      x-amazon-apigateway-integration:
        type: HTTP_PROXY
        httpMethod: GET
        uri: ${ALB_LISTENER_ARN}
        connectionType: VPC_LINK
        connectionId: ${VPC_LINK_ID}
        payloadFormatVersion: "1.0"
        requestParameters:
          # Transform: /accounts/123 → /account-svc/api/v1/accounts/123
          overwrite:path: /account-svc/api/v1/accounts/${request.path.accountId}
```

### ALB Listener Rules (CloudFormation)

```yaml
AccountServiceRule:
  Type: AWS::ElasticLoadBalancingV2::ListenerRule
  Properties:
    ListenerArn: !Ref ALBListener
    Priority: 10
    Conditions:
      - Field: path-pattern
        Values:
          - "/account-svc/*"
    Actions:
      - Type: forward
        TargetGroupArn: !Ref AccountServiceTargetGroup
        # Note: ALB v2 supports path rewriting with "redirect" action type
        # For forwarding, the path goes to target as-is
```

### ECS Task Definition - Application Config

```yaml
# Spring Boot application.yml
server:
  servlet:
    context-path: /account-svc  # If app handles prefix
    # OR
    context-path: /             # If ALB/infra strips prefix
```

---

## Decision Matrix

| Factor | Strip at Each Layer | Passthrough Full Path |
|--------|--------------------|-----------------------|
| **Application Simplicity** | ✓ Clean paths | ✗ Must handle prefixes |
| **Infrastructure Complexity** | ✗ More config per layer | ✓ Simple forwarding |
| **Debugging** | Harder to trace | Easier to trace full path |
| **Team Coupling** | Loose coupling | Tight coupling |
| **Path Conflicts** | Less likely | More likely |
| **Recommended For** | Production APIs | Internal/Debug |

---

## Recommendation

For your architecture:

```
Transit Gateway → API Gateway → ALB → ECS Fargate
```

**Use Path Stripping Strategy:**

1. **Transit Gateway Level**: Strip `/app-gateway-name` prefix
2. **API Gateway Level**: Map clean paths and add service prefix for ALB routing
3. **ALB Level**: Route by service prefix, optionally strip before ECS
4. **ECS Application**: Receives clean API paths (`/api/v1/resource`)

This approach:
- Keeps applications decoupled from infrastructure routing
- Allows each team to manage their layer independently
- Follows REST API best practices for clean URLs
- Simplifies application development and testing

---

## Related Documentation

- [01: Selective Path Mapping](../01-selective-path-mapping/README.md)
- [AWS ALB Path-Based Routing](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html#path-conditions)
- [API Gateway Path Parameters](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-parameter-mapping.html)
