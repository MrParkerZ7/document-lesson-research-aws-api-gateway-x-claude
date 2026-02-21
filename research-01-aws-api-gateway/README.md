# Research 01: AWS API Gateway Path Mapping

## Overview

This research explores path mapping strategies when using AWS API Gateway with backend services, specifically addressing real-world routing scenarios in multi-layer architectures.

---

## Research Topics

### [01: Selective Path Mapping](./01-selective-path-mapping/README.md)

**Question:** Can API Gateway map to specific ALB paths without exposing all subpaths?

**Answer:** Yes - use specific routes instead of `{proxy+}`.

Key concepts:
- Selective vs greedy path exposure
- HTTP API for direct ALB integration
- Path rewriting with `overwrite:path`
- Security through route isolation

![Selective Path Mapping](./01-selective-path-mapping/01-selective-path-mapping.png)

---

### [02: Multi-Hop Path Mapping](./02-multi-hop-path-mapping/README.md)

**Question:** How do path prefixes work across multiple routing layers?

**Scenario:**
```
Transit Gateway → API Gateway → ALB → ECS Fargate
```

**Answer:** Each layer should strip its routing prefix before forwarding.

Key concepts:
- Path accumulation problem
- Layer-by-layer path transformation
- Separation of routing concerns
- Application receives clean REST paths

![Multi-Hop Path Mapping](./02-multi-hop-path-mapping/01.2-multi-hop-path-mapping.png)

---

### [03: Demo - Multi-Hop with Terraform & Kotlin](./03-demo-multi-hop-terraform/README.md)

**Purpose:** Working demonstration of multi-hop path mapping architecture.

**Stack:**
- **Infrastructure:** Terraform on AWS (API Gateway, ALB, ECS Fargate)
- **Applications:** Kotlin Spring Boot microservices
- **Local Dev:** Docker Compose with NGINX (simulates ALB)

Key features:
- Complete monorepo structure
- Reusable Terraform modules
- Path rewriting via `overwrite:path`
- Spring Boot context-path for service prefix handling

```bash
# Quick start - local development
cd 03-demo-multi-hop-terraform
make local-up

# Test endpoints (via NGINX simulating ALB)
curl http://localhost:8080/account-svc/api/v1/accounts/123
curl http://localhost:8080/transfer-svc/api/v1/transfers/TRF001
```

---

## Architecture Pattern

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        MULTI-HOP PATH TRANSFORMATION                         │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Client: tgw.example.com/payment-gateway/accounts/123                        │
│                                    │                                         │
│                                    ▼                                         │
│  Transit Gateway: Strip /payment-gateway → /accounts/123                     │
│                                    │                                         │
│                                    ▼                                         │
│  API Gateway: Add prefix → /account-svc/api/v1/accounts/123                  │
│                                    │                                         │
│                                    ▼                                         │
│  ALB: Route + Strip → /api/v1/accounts/123                                   │
│                                    │                                         │
│                                    ▼                                         │
│  ECS Application: Receives clean path GET /api/v1/accounts/123               │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Takeaways

| Layer | Responsibility | Path Handling |
|-------|---------------|---------------|
| Transit Gateway | Route to correct API Gateway | Strip gateway prefix |
| API Gateway | Route to correct ALB target | Map paths + add service prefix |
| ALB | Route to correct ECS service | Strip service prefix (optional) |
| ECS Application | Handle business logic | Receive clean REST paths |

---

## Related Lessons

- [Lesson 01: AWS API Gateway - Complete Guide](../lesson-01-aws-api-gateway/README.md)
