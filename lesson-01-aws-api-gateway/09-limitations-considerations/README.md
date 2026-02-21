# 09. Limitations and Considerations

## Overview

While AWS API Gateway is a powerful service, it has limitations that may affect your architecture decisions. Understanding these limitations upfront helps avoid surprises and allows you to plan appropriate workarounds.

## Learning Objectives

- Understand API Gateway quotas and limits
- Identify features NOT supported by API Gateway
- Learn workarounds for common limitations
- Know when to consider alternatives

## 1. Service Quotas and Limits

### Request/Response Limits

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Request/Response Limits                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Payload Size                                                            │
│  ├── REST API: 10 MB max payload                                       │
│  ├── HTTP API: 10 MB max payload                                       │
│  └── WebSocket API: 128 KB per frame, 32 KB default                    │
│                                                                          │
│  Timeout                                                                 │
│  ├── REST API: 29 seconds maximum                                      │
│  ├── HTTP API: 30 seconds maximum                                      │
│  └── Lambda timeout: Must be <= API Gateway timeout                    │
│                                                                          │
│  URL Length                                                              │
│  └── 8,192 bytes maximum (including query strings)                     │
│                                                                          │
│  Headers                                                                 │
│  ├── Total header size: 10,240 bytes                                   │
│  └── Single header value: 2,048 bytes                                  │
│                                                                          │
│  Request Parameters                                                      │
│  ├── Path parameters: No limit                                         │
│  ├── Query string parameters: Combined limit in URL length             │
│  └── Headers: No explicit limit                                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Throughput Limits

| Limit | Default | Adjustable | Notes |
|-------|---------|------------|-------|
| Requests per second (Regional) | 10,000 | Yes | Per account per region |
| Requests per second (Edge) | 10,000 | Yes | Shared across regions |
| Burst limit | 5,000 | Yes | Concurrent requests |
| WebSocket connections | 500 | Yes | Per API per stage |
| WebSocket messages/sec | 10,000 | Yes | Per account |

### Resource Limits

| Resource | Limit | Adjustable |
|----------|-------|------------|
| APIs per account | 600 | Yes |
| API keys per account | 10,000 | Yes |
| Usage plans per account | 300 | Yes |
| Custom domain names | 120 | Yes |
| Resources per API | 300 | No |
| Stages per API | 10 | No |
| Authorizers per API | 10 | No |
| VPC Links (REST) | 20 | Yes |
| VPC Links (HTTP) | 10 | Yes |

### Impact of Limits

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Limit Impact Scenarios                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Scenario 1: Large File Upload                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Problem: 10 MB limit prevents large file uploads                │    │
│  │                                                                   │    │
│  │  Workaround:                                                      │    │
│  │  • Generate pre-signed S3 URL via API Gateway                   │    │
│  │  • Client uploads directly to S3                                 │    │
│  │  • S3 triggers Lambda for processing                             │    │
│  │                                                                   │    │
│  │  Client → API GW → Lambda (get URL) → S3 (direct upload)        │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Scenario 2: Long-Running Operations                                     │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Problem: 29-30 second timeout for reports, exports              │    │
│  │                                                                   │    │
│  │  Workaround:                                                      │    │
│  │  • Async pattern with polling                                    │    │
│  │  • Step Functions for orchestration                              │    │
│  │  • WebSocket for progress updates                                │    │
│  │                                                                   │    │
│  │  POST /jobs → 202 Accepted + job ID                             │    │
│  │  GET /jobs/{id} → Poll for completion                           │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Scenario 3: High Burst Traffic                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Problem: Flash sales, viral content exceed limits               │    │
│  │                                                                   │    │
│  │  Workaround:                                                      │    │
│  │  • Request limit increase ahead of time                          │    │
│  │  • Use CloudFront with edge caching                             │    │
│  │  • Implement client-side retry with backoff                     │    │
│  │  • Queue requests with SQS for processing                       │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 2. Features NOT Supported

### Protocol Limitations

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Protocol Support Matrix                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Supported                     │ Not Supported                          │
│  ─────────────────────────────────────────────────────────────────────  │
│  • HTTP/1.1                    │ • gRPC (use ALB)                       │
│  • HTTPS (TLS 1.2+)           │ • HTTP/2 to backend (REST API)        │
│  • WebSocket                   │ • HTTP/3 (QUIC)                       │
│                                │ • TCP/UDP (raw sockets)               │
│                                │ • GraphQL (native - use AppSync)      │
│                                │ • SOAP (no native - transform in VTL) │
│                                │ • Server-Sent Events (SSE)            │
│                                │ • Long polling (>30s)                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### gRPC Workarounds

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    gRPC with AWS                                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Option 1: ALB (Recommended)                                             │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  gRPC Client → ALB → ECS/EKS (gRPC service)                     │    │
│  │                                                                   │    │
│  │  • Full gRPC support                                             │    │
│  │  • HTTP/2 end-to-end                                             │    │
│  │  • No API management features                                    │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Option 2: gRPC-Web with API Gateway                                    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Browser → API Gateway → Envoy (transcode) → gRPC service       │    │
│  │                                                                   │    │
│  │  • Works for web clients                                         │    │
│  │  • Additional proxy layer                                        │    │
│  │  • Some gRPC features lost                                       │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Option 3: gRPC-JSON Transcoding                                        │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  REST Client → API Gateway → Lambda → gRPC service              │    │
│  │                                                                   │    │
│  │  • REST interface for gRPC services                             │    │
│  │  • Lambda handles transcoding                                    │    │
│  │  • Higher latency                                                │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### GraphQL Alternatives

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    GraphQL Options                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  API Gateway + GraphQL (Not Recommended)                                │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Client → API Gateway → Lambda (GraphQL server)                  │    │
│  │                                                                   │    │
│  │  Issues:                                                          │    │
│  │  • All requests go to single Lambda (single endpoint)           │    │
│  │  • No caching per resolver                                       │    │
│  │  • No subscription support                                       │    │
│  │  • Cold starts affect all queries                               │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  AWS AppSync (Recommended)                                               │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Client → AppSync → DynamoDB/Lambda/HTTP                        │    │
│  │                                                                   │    │
│  │  Benefits:                                                        │    │
│  │  • Native GraphQL support                                        │    │
│  │  • Per-resolver caching                                          │    │
│  │  • Real-time subscriptions                                       │    │
│  │  • Direct data source integrations                              │    │
│  │  • Offline support (Amplify)                                    │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Missing Features Comparison

| Feature | API Gateway | Available In |
|---------|-------------|--------------|
| GraphQL native | No | AppSync |
| gRPC | No | ALB, Cloud Map |
| Service mesh | No | App Mesh, EKS |
| Circuit breaker | No | App Mesh, Kong |
| Retry policies | Limited | Step Functions |
| Distributed tracing | X-Ray only | X-Ray, Datadog |
| API documentation hosting | No | Third-party |
| Developer portal | No | Third-party, Apigee |
| API monetization | No | Third-party |
| Request queuing | No | SQS + Lambda |
| Response streaming | No | Lambda streaming |
| HTTP/2 to origin | HTTP API only | ALB |

## 3. HTTP API Limitations vs REST API

### Features Missing in HTTP API

| Feature | REST API | HTTP API | Impact |
|---------|----------|----------|--------|
| Request validation | Yes | No | Must validate in Lambda |
| Response transformation | Yes (VTL) | No | Return from Lambda |
| Caching | Built-in | No | Use CloudFront |
| API keys | Yes | No | Implement in Lambda |
| Usage plans | Yes | No | Custom implementation |
| Request transformation | Yes (VTL) | Parameter mapping only | Limited transformation |
| Resource policies | Yes | No | Use IAM/authorizers |
| Edge-optimized | Yes | No | Use CloudFront |
| Execution logging | Yes | No | Lambda logging only |
| AWS X-Ray (detailed) | Yes | Limited | Basic tracing |
| Private integrations | NLB only | ALB, NLB, Cloud Map | More flexible in HTTP |

### Decision Matrix

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    REST vs HTTP API Decision                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Must use REST API if you need:                                          │
│  • Request/response transformation (VTL)                                │
│  • Built-in response caching                                            │
│  • API keys with usage plans                                            │
│  • Request validation at gateway                                        │
│  • Edge-optimized endpoints                                             │
│  • Resource policies                                                     │
│  • Detailed execution logging                                           │
│                                                                          │
│  Can use HTTP API if:                                                    │
│  • Simple proxy to Lambda or HTTP                                       │
│  • JWT authentication sufficient                                        │
│  • Validation happens in Lambda                                         │
│  • Cost optimization is priority                                        │
│  • Low latency is critical                                              │
│  • Using CloudFront for caching                                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 4. WebSocket Limitations

### WebSocket-Specific Limits

| Limit | Value | Notes |
|-------|-------|-------|
| Connection duration | 2 hours max | Must reconnect after |
| Idle timeout | 10 minutes | Send ping to keep alive |
| Message size | 128 KB (32 KB default) | Can increase to 128 KB |
| Connection rate | 500/second | Per API |
| Concurrent connections | 500 default | Adjustable |

### WebSocket Missing Features

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    WebSocket Limitations                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Not Supported:                                                          │
│  • Binary WebSocket frames (text only)                                  │
│  • Automatic reconnection (client must implement)                       │
│  • Connection migration between regions                                 │
│  • Built-in pub/sub (must implement with DynamoDB)                     │
│  • Guaranteed message ordering                                          │
│  • Message acknowledgment                                               │
│  • Presence detection (must build)                                      │
│                                                                          │
│  Workarounds:                                                            │
│  • Binary: Base64 encode data                                           │
│  • Reconnection: Client-side exponential backoff                       │
│  • Pub/sub: DynamoDB + Lambda fan-out                                  │
│  • Ordering: Include sequence numbers                                   │
│  • Presence: Heartbeat + connection table                               │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 5. VPC and Networking Limitations

### Private API Considerations

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Private API Limitations                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  VPC Endpoint Requirements:                                              │
│  • Must create interface VPC endpoint for execute-api                  │
│  • Endpoint costs: ~$0.01/hour + data transfer                         │
│  • DNS must be configured (private DNS or Route 53)                    │
│                                                                          │
│  Cross-Account Access:                                                   │
│  • Requires resource policy                                             │
│  • VPC endpoint in calling account                                      │
│  • Complex setup for many accounts                                      │
│                                                                          │
│  Regional Constraints:                                                   │
│  • Private APIs are regional only                                       │
│  • No edge optimization                                                 │
│  • Cross-region requires VPC peering                                   │
│                                                                          │
│  Common Issues:                                                          │
│  • DNS resolution failures                                              │
│  • Security group misconfigurations                                    │
│  • VPC endpoint policy conflicts                                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### VPC Link Limitations

| Aspect | REST API (VPC Link v1) | HTTP API (VPC Link v2) |
|--------|------------------------|------------------------|
| Target | NLB only | ALB, NLB, Cloud Map |
| Provisioning | Takes minutes | Near instant |
| IP addressing | NLB IP changes | Stable |
| HTTP/2 | No | Yes |
| gRPC | No | No (ALB supports, not via API GW) |

## 6. Operational Limitations

### Deployment Limitations

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Deployment Constraints                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Stages:                                                                 │
│  • Maximum 10 stages per API                                            │
│  • Cannot rename stages                                                 │
│  • Stage deletion can break custom domains                              │
│                                                                          │
│  Deployments:                                                            │
│  • No automatic rollback                                                │
│  • Manual deployment required (REST API)                                │
│  • No blue-green native support (use custom domains)                   │
│                                                                          │
│  Canary:                                                                 │
│  • REST API only                                                        │
│  • Single canary per stage                                              │
│  • Manual promotion required                                            │
│                                                                          │
│  Updates:                                                                │
│  • API changes require redeployment                                    │
│  • Some changes cause brief downtime                                   │
│  • No zero-downtime guarantee for all changes                          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Logging Limitations

| Aspect | Limitation | Workaround |
|--------|------------|------------|
| Log retention | No auto-expiration | Set CloudWatch retention policy |
| Log format | Fixed fields | Use Lambda for custom logging |
| Request body logging | Can expose sensitive data | Disable or mask in Lambda |
| Real-time analysis | Not supported | Stream to Kinesis/OpenSearch |
| Log volume | High cost at scale | Sample requests |

## 7. Cost Considerations

### Hidden Costs

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Total Cost Considerations                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  API Gateway Costs:                                                      │
│  • Request charges ($1.00-$3.50/million)                               │
│  • Cache ($0.02-$3.80/hour depending on size)                          │
│  • Data transfer out                                                    │
│                                                                          │
│  Related Costs Often Overlooked:                                         │
│  • Lambda invocations                                                   │
│  • Lambda duration (longer = more expensive)                           │
│  • CloudWatch Logs storage                                              │
│  • VPC Link (NLB/ALB costs)                                            │
│  • VPC endpoints for private APIs                                      │
│  • Custom domain certificates (free with ACM, but renewal ops)        │
│  • WAF rules ($5/month + $0.60/million requests)                       │
│                                                                          │
│  Cost Traps:                                                             │
│  • Over-sized cache that's underutilized                               │
│  • Debug logging in production (high volume)                           │
│  • Large response payloads (data transfer)                             │
│  • Unnecessary validation in Lambda (compute time)                     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 8. Workaround Summary

| Limitation | Workaround |
|------------|------------|
| 10 MB payload | Pre-signed S3 URLs |
| 30s timeout | Async processing with polling |
| No gRPC | Use ALB directly |
| No GraphQL | Use AppSync |
| No caching (HTTP API) | CloudFront in front |
| No API keys (HTTP API) | Lambda authorizer |
| No request validation (HTTP API) | Validate in Lambda |
| No streaming | Lambda response streaming (separate) |
| Binary WebSocket | Base64 encoding |
| 2-hour WebSocket limit | Client reconnection logic |
| Cross-region | CloudFront or Global Accelerator |

## 9. When NOT to Use API Gateway

### Consider Alternatives When

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    When to Consider Alternatives                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Use ALB instead when:                                                   │
│  • gRPC is required                                                     │
│  • Latency is critical (<10ms overhead)                                │
│  • Long-running connections (>30s)                                     │
│  • High volume cost optimization                                        │
│  • Container-native features needed                                     │
│                                                                          │
│  Use AppSync instead when:                                               │
│  • Building GraphQL APIs                                                │
│  • Real-time subscriptions needed                                       │
│  • Complex data aggregation                                             │
│  • Offline-first mobile apps                                            │
│                                                                          │
│  Use Kong/Apigee instead when:                                           │
│  • Multi-cloud deployment                                               │
│  • Need developer portal                                                │
│  • API monetization required                                            │
│  • Advanced traffic management                                          │
│                                                                          │
│  Use direct integration when:                                            │
│  • Internal service-to-service                                          │
│  • Simple Lambda URL sufficient                                         │
│  • No API management needed                                             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Key Takeaways

1. **Know the limits** - Payload, timeout, and throughput limits are hard constraints
2. **Plan for workarounds** - Large files need S3, long tasks need async
3. **HTTP API has tradeoffs** - Cheaper but fewer features
4. **gRPC needs ALB** - API Gateway doesn't support it
5. **GraphQL needs AppSync** - Don't force it through API Gateway
6. **Calculate total cost** - Include all related services
7. **Request limit increases early** - Some increases take time

## Further Reading

- [API Gateway Quotas](https://docs.aws.amazon.com/apigateway/latest/developerguide/limits.html)
- [Request Limit Increase](https://docs.aws.amazon.com/servicequotas/latest/userguide/request-quota-increase.html)
- [Best Practices](https://docs.aws.amazon.com/apigateway/latest/developerguide/best-practices.html)
- [Troubleshooting](https://docs.aws.amazon.com/apigateway/latest/developerguide/troubleshooting.html)
