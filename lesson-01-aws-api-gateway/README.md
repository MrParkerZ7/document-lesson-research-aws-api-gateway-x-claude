# Lesson 01: AWS API Gateway - Complete Guide

## Overview

AWS API Gateway is a fully managed service that enables developers to create, publish, maintain, monitor, and secure APIs at any scale. It acts as a "front door" for applications to access data, business logic, or functionality from backend services.

## Learning Objectives

By the end of this lesson, you will be able to:

1. Understand what AWS API Gateway is and its role in modern architectures
2. Differentiate between REST API, HTTP API, and WebSocket API types
3. Configure API Gateway integrations with various AWS services
4. Implement authentication and authorization strategies
5. Deploy and manage API versions effectively
6. Compare API Gateway with alternative solutions
7. Apply best practices for production deployments

## Sub-Lessons

| # | Topic | Description |
|---|-------|-------------|
| 01 | [Introduction](./01-introduction/README.md) | What is API Gateway, use cases, and architecture overview |
| 02 | [API Gateway Types](./02-api-gateway-types/README.md) | REST API vs HTTP API vs WebSocket API comparison |
| 03 | [Core Features](./03-core-features/README.md) | Request/Response transformations, caching, throttling |
| 04 | [Integration Patterns](./04-integration-patterns/README.md) | Lambda, HTTP, AWS Services, VPC Link integrations |
| 05 | [Security & Authentication](./05-security-authentication/README.md) | IAM, Cognito, Lambda Authorizers, API Keys |
| 06 | [Deployment & Management](./06-deployment-management/README.md) | Stages, versions, canary deployments, custom domains |
| 07 | [Comparison with Alternatives](./07-comparison-alternatives/README.md) | vs ALB, Kong, Apigee, Azure API Management |
| 08 | [Best Practices](./08-best-practices/README.md) | Design patterns, performance optimization, cost management |
| 09 | [Limitations & Considerations](./09-limitations-considerations/README.md) | What API Gateway doesn't support and workarounds |

## Quick Reference

### When to Use AWS API Gateway

| Use Case | Recommended |
|----------|-------------|
| Serverless REST APIs with Lambda | Yes |
| Real-time WebSocket applications | Yes |
| Simple HTTP proxy to backend | Yes (HTTP API) |
| High-throughput, low-latency APIs | Consider (HTTP API or ALB) |
| GraphQL APIs | Limited (consider AppSync) |
| gRPC APIs | No |
| TCP/UDP protocols | No |

### Pricing Model Overview

| API Type | Pricing Basis |
|----------|---------------|
| REST API | Per million requests + data transfer + cache |
| HTTP API | Per million requests (up to 71% cheaper than REST) |
| WebSocket API | Per million messages + connection minutes |

## Prerequisites

- AWS Account with appropriate IAM permissions
- Basic understanding of REST APIs and HTTP protocols
- Familiarity with AWS Lambda (recommended)
- Understanding of JSON and API design concepts

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              CLIENTS                                     │
│         (Web Apps, Mobile Apps, IoT Devices, Third-party APIs)          │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         AWS API GATEWAY                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │   REST API  │  │  HTTP API   │  │ WebSocket   │  │  Private    │    │
│  │             │  │             │  │    API      │  │    API      │    │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │
│                                                                          │
│  Features: Authentication | Throttling | Caching | Monitoring | WAF     │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        ▼                         ▼                         ▼
┌───────────────┐       ┌───────────────┐       ┌───────────────────────┐
│  AWS Lambda   │       │  HTTP/HTTPS   │       │    AWS Services       │
│  Functions    │       │  Endpoints    │       │  (DynamoDB, S3, SQS,  │
│               │       │  (EC2, ECS,   │       │   Step Functions,     │
│               │       │   On-prem)    │       │   Kinesis, etc.)      │
└───────────────┘       └───────────────┘       └───────────────────────┘
```

## Key Takeaways

1. **API Gateway is a managed service** - No infrastructure to manage, automatic scaling
2. **Choose the right API type** - REST API for full features, HTTP API for cost/performance
3. **Security is built-in** - Multiple authentication options available
4. **Pay per use** - No minimum fees, pay only for requests received
5. **Deep AWS integration** - Native integration with 100+ AWS services

## Further Reading

- [AWS API Gateway Documentation](https://docs.aws.amazon.com/apigateway/)
- [API Gateway Pricing](https://aws.amazon.com/api-gateway/pricing/)
- [API Gateway Quotas and Limits](https://docs.aws.amazon.com/apigateway/latest/developerguide/limits.html)
- [Serverless Application Model (SAM)](https://aws.amazon.com/serverless/sam/)
