# 11. Selective Path Exposure with ALB

## Research Question

> Can API Gateway map to an ALB with a specific path without exposing all subpaths?
>
> Example: Expose only `some.alb.com/api/v1/document` instead of `some.alb.com/*`

## Answer: Yes

API Gateway can selectively expose specific ALB paths by creating individual resource mappings instead of using greedy path variables (`{proxy+}`).

---

## The Problem

When integrating API Gateway with an ALB backend, you may have:

```
ALB Backend (some.alb.com):
├── /api/v1/document      ← Want to expose
├── /api/v1/document/{id} ← Want to expose
├── /api/v1/admin         ← Internal only, DO NOT expose
├── /api/v1/internal      ← Internal only, DO NOT expose
├── /health               ← Internal only, DO NOT expose
└── /metrics              ← Internal only, DO NOT expose
```

**Goal:** Expose only `/api/v1/document` endpoints through API Gateway.

---

## Solution: Specific Path Mapping

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           INTERNET                                       │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         API GATEWAY (HTTP API)                           │
│                                                                          │
│   Resources (Only these are exposed):                                    │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │  GET  /document      → maps to → /api/v1/document               │   │
│   │  POST /document      → maps to → /api/v1/document               │   │
│   │  GET  /document/{id} → maps to → /api/v1/document/{id}          │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  │ VPC Link
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              VPC                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    ALB (some.alb.com)                              │  │
│  │                                                                    │  │
│  │   /api/v1/document      ✓ Accessible via API Gateway              │  │
│  │   /api/v1/document/{id} ✓ Accessible via API Gateway              │  │
│  │   /api/v1/admin         ✗ NOT exposed (no API Gateway route)      │  │
│  │   /api/v1/internal      ✗ NOT exposed (no API Gateway route)      │  │
│  │   /health               ✗ NOT exposed (no API Gateway route)      │  │
│  │   /metrics              ✗ NOT exposed (no API Gateway route)      │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## HTTP API Configuration (Recommended for ALB)

### Why HTTP API?

| Feature | HTTP API | REST API |
|---------|----------|----------|
| ALB Direct Integration | ✓ Yes | ✗ No (requires NLB) |
| VPC Link Support | ✓ ALB, NLB, Cloud Map | NLB only |
| Cost | ~70% cheaper | Higher |
| Latency | Lower | Higher |

### OpenAPI Specification

```yaml
openapi: "3.0.1"
info:
  title: "Selective ALB Exposure API"
  version: "1.0.0"

paths:
  /document:
    get:
      summary: "Get all documents"
      x-amazon-apigateway-integration:
        type: HTTP_PROXY
        httpMethod: GET
        uri: arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/my-alb/50dc6c495c0c9188/...
        connectionType: VPC_LINK
        connectionId: "${stageVariables.vpcLinkId}"
        payloadFormatVersion: "1.0"
        requestParameters:
          overwrite:path: /api/v1/document

    post:
      summary: "Create document"
      x-amazon-apigateway-integration:
        type: HTTP_PROXY
        httpMethod: POST
        uri: arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/my-alb/50dc6c495c0c9188/...
        connectionType: VPC_LINK
        connectionId: "${stageVariables.vpcLinkId}"
        payloadFormatVersion: "1.0"
        requestParameters:
          overwrite:path: /api/v1/document

  /document/{documentId}:
    get:
      summary: "Get document by ID"
      parameters:
        - name: documentId
          in: path
          required: true
          schema:
            type: string
      x-amazon-apigateway-integration:
        type: HTTP_PROXY
        httpMethod: GET
        uri: arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/my-alb/50dc6c495c0c9188/...
        connectionType: VPC_LINK
        connectionId: "${stageVariables.vpcLinkId}"
        payloadFormatVersion: "1.0"
        requestParameters:
          overwrite:path: /api/v1/document/${request.path.documentId}
```

### CloudFormation / SAM Template

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: Selective ALB Path Exposure

Resources:
  # VPC Link for private ALB connection
  VpcLink:
    Type: AWS::ApiGatewayV2::VpcLink
    Properties:
      Name: alb-vpc-link
      SubnetIds:
        - !Ref PrivateSubnet1
        - !Ref PrivateSubnet2
      SecurityGroupIds:
        - !Ref VpcLinkSecurityGroup

  # HTTP API
  HttpApi:
    Type: AWS::ApiGatewayV2::Api
    Properties:
      Name: selective-exposure-api
      ProtocolType: HTTP

  # Integration to ALB
  AlbIntegration:
    Type: AWS::ApiGatewayV2::Integration
    Properties:
      ApiId: !Ref HttpApi
      IntegrationType: HTTP_PROXY
      IntegrationMethod: ANY
      IntegrationUri: !Ref AlbListenerArn
      ConnectionType: VPC_LINK
      ConnectionId: !Ref VpcLink
      PayloadFormatVersion: "1.0"

  # Route: GET /document
  GetDocumentsRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref HttpApi
      RouteKey: "GET /document"
      Target: !Sub "integrations/${AlbIntegration}"

  # Route: POST /document
  CreateDocumentRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref HttpApi
      RouteKey: "POST /document"
      Target: !Sub "integrations/${AlbIntegration}"

  # Route: GET /document/{documentId}
  GetDocumentByIdRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref HttpApi
      RouteKey: "GET /document/{documentId}"
      Target: !Sub "integrations/${AlbIntegration}"

  # Stage
  ApiStage:
    Type: AWS::ApiGatewayV2::Stage
    Properties:
      ApiId: !Ref HttpApi
      StageName: prod
      AutoDeploy: true
```

---

## Path Rewriting Patterns

### Pattern 1: Simple Path Prefix

```
API Gateway Path    →    ALB Path
─────────────────────────────────────
/document           →    /api/v1/document
/document/{id}      →    /api/v1/document/{id}
```

**Configuration:**
```yaml
requestParameters:
  overwrite:path: /api/v1/document
```

### Pattern 2: Version Abstraction

```
API Gateway Path    →    ALB Path
─────────────────────────────────────
/v1/document        →    /api/v1/document
/v2/document        →    /api/v2/document
```

**Configuration using stage variables:**
```yaml
requestParameters:
  overwrite:path: /api/${stageVariables.apiVersion}/document
```

### Pattern 3: Path Variable Mapping

```
API Gateway Path         →    ALB Path
─────────────────────────────────────────────
/doc/{id}                →    /api/v1/document/{id}
/doc/{id}/attachment     →    /api/v1/document/{id}/files
```

**Configuration:**
```yaml
requestParameters:
  overwrite:path: /api/v1/document/${request.path.id}/files
```

---

## Comparison: Selective vs Greedy Path

| Aspect | Selective Path | Greedy Path (`{proxy+}`) |
|--------|---------------|--------------------------|
| **Security** | ✓ Only specified paths exposed | ✗ All backend paths exposed |
| **Control** | ✓ Full control over each route | ✗ Pass-through behavior |
| **Maintenance** | Need to add routes manually | Auto-forwards all paths |
| **Path Transformation** | ✓ Can rewrite paths | Limited transformation |
| **Use Case** | Public APIs, security-sensitive | Internal APIs, microservices |

### When to Use Selective Path

- Public-facing APIs where you control the surface area
- Backend has internal endpoints that should never be exposed
- Need to abstract or simplify backend URL structure
- Different authentication per endpoint

### When to Use Greedy Path

- Full backend proxy (expose everything)
- Microservices where backend controls routing
- Rapid development without API Gateway route management

---

## Security Considerations

### 1. Defense in Depth

Even with selective path exposure, implement additional security:

```
┌─────────────────────────────────────────┐
│           API Gateway                    │
│  • Selective path exposure              │
│  • Request validation                   │
│  • Rate limiting                        │
│  • WAF integration                      │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│              ALB                         │
│  • Security groups (allow only VPC Link)│
│  • Path-based routing rules             │
│  • Health checks on internal paths only │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│           Backend Service                │
│  • Authentication verification          │
│  • Authorization checks                 │
│  • Input validation                     │
└─────────────────────────────────────────┘
```

### 2. ALB Security Group

Restrict ALB to only accept traffic from VPC Link:

```yaml
AlbSecurityGroup:
  Type: AWS::EC2::SecurityGroup
  Properties:
    GroupDescription: ALB security group
    VpcId: !Ref VPC
    SecurityGroupIngress:
      # Only allow traffic from VPC Link security group
      - IpProtocol: tcp
        FromPort: 80
        ToPort: 80
        SourceSecurityGroupId: !Ref VpcLinkSecurityGroup
```

### 3. Internal Paths Protection

Even if someone discovers internal paths, they cannot access them:

```
Request: GET https://api.example.com/api/v1/admin
Response: 404 Not Found (no route in API Gateway)

Request: GET https://api.example.com/health
Response: 404 Not Found (no route in API Gateway)
```

---

## REST API Alternative (If ALB Must Use NLB)

If you must use REST API, you need an NLB in front of the ALB:

```
API Gateway (REST) → VPC Link → NLB → ALB → Backend
```

```yaml
# REST API Integration
x-amazon-apigateway-integration:
  type: HTTP_PROXY
  httpMethod: GET
  uri: http://internal-nlb.example.com/api/v1/document
  connectionType: VPC_LINK
  connectionId: "${stageVariables.vpcLinkId}"
  requestParameters:
    integration.request.path.id: method.request.path.id
```

---

## Best Practices

1. **Use HTTP API for ALB** - Direct ALB support, lower cost, lower latency

2. **Explicit Route Definition** - Define each exposed route explicitly rather than using wildcards

3. **Path Transformation** - Use `overwrite:path` to map clean API paths to backend paths

4. **Security Groups** - Restrict ALB to only accept VPC Link traffic

5. **Documentation** - Document which paths are exposed vs internal

6. **Monitoring** - Monitor both API Gateway and ALB access logs for unexpected patterns

---

## Summary

| Question | Answer |
|----------|--------|
| Can API Gateway map to specific ALB path? | **Yes** |
| How? | Create specific routes, don't use `{proxy+}` |
| Which API type? | HTTP API (direct ALB support) |
| Can I rewrite paths? | Yes, using `overwrite:path` |
| Are unexposed paths secure? | Yes, API Gateway returns 404 |

---

## Related Documentation

- [10. Resource Mapping](../10-resource-mapping/README.md)
- [04. Integration Patterns](../04-integration-patterns/README.md)
- [AWS HTTP API VPC Link](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vpc-links.html)
