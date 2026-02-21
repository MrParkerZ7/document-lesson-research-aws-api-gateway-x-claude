# Research 01: API Gateway + ALB Path Mapping

## Research Questions

### Q1: Can API Gateway map to specific ALB paths without exposing all subpaths?

**Question:**
> Can API Gateway map to an ALB with a specific path?
> Example: Expose only `some.alb.com/api/v1/document` instead of `some.alb.com/*`

**Answer:** Yes

API Gateway can selectively expose specific ALB paths by creating individual resource mappings instead of using greedy path variables (`{proxy+}`).

---

## Solution Overview

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
│   Exposed Routes:                                                        │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │  GET  /document      → /api/v1/document                         │   │
│   │  POST /document      → /api/v1/document                         │   │
│   │  GET  /document/{id} → /api/v1/document/{id}                    │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │ VPC Link
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              VPC                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    ALB (some.alb.com)                              │  │
│  │                                                                    │  │
│  │   /api/v1/document      ✓ Accessible via API Gateway              │  │
│  │   /api/v1/document/{id} ✓ Accessible via API Gateway              │  │
│  │   /api/v1/admin         ✗ NOT exposed                             │  │
│  │   /api/v1/internal      ✗ NOT exposed                             │  │
│  │   /health               ✗ NOT exposed                             │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Key Concepts

### Why HTTP API for ALB?

| Feature | HTTP API | REST API |
|---------|----------|----------|
| ALB Direct Integration | ✓ Yes | ✗ No (requires NLB) |
| VPC Link Support | ALB, NLB, Cloud Map | NLB only |
| Cost | ~70% cheaper | Higher |
| Latency | Lower | Higher |

### Selective vs Greedy Path

| Aspect | Selective Path | Greedy Path (`{proxy+}`) |
|--------|---------------|--------------------------|
| **Security** | ✓ Only specified paths exposed | ✗ All backend paths exposed |
| **Control** | ✓ Full control over each route | ✗ Pass-through behavior |
| **Maintenance** | Need to add routes manually | Auto-forwards all paths |
| **Path Transformation** | ✓ Can rewrite paths | Limited transformation |
| **Use Case** | Public APIs, security-sensitive | Internal APIs, microservices |

---

## Configuration Examples

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
        uri: arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/my-alb/...
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
        uri: arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/my-alb/...
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

Resources:
  # VPC Link
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

  # Integration
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

  # Route: GET /document/{documentId}
  GetDocumentByIdRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref HttpApi
      RouteKey: "GET /document/{documentId}"
      Target: !Sub "integrations/${AlbIntegration}"
```

---

## Path Rewriting Patterns

### Pattern 1: Simple Path Prefix

```
API Gateway Path    →    ALB Path
─────────────────────────────────────
/document           →    /api/v1/document
```

```yaml
requestParameters:
  overwrite:path: /api/v1/document
```

### Pattern 2: Path Variable Mapping

```
API Gateway Path    →    ALB Path
─────────────────────────────────────
/doc/{id}           →    /api/v1/document/{id}
```

```yaml
requestParameters:
  overwrite:path: /api/v1/document/${request.path.id}
```

### Pattern 3: Version Abstraction

```
API Gateway Path    →    ALB Path
─────────────────────────────────────
/v1/document        →    /api/v1/document
/v2/document        →    /api/v2/document
```

```yaml
requestParameters:
  overwrite:path: /api/${stageVariables.apiVersion}/document
```

---

## Security Considerations

### 1. ALB Security Group

Restrict ALB to only accept traffic from VPC Link:

```yaml
AlbSecurityGroup:
  Type: AWS::EC2::SecurityGroup
  Properties:
    GroupDescription: ALB security group
    VpcId: !Ref VPC
    SecurityGroupIngress:
      - IpProtocol: tcp
        FromPort: 80
        ToPort: 80
        SourceSecurityGroupId: !Ref VpcLinkSecurityGroup
```

### 2. Unexposed Paths Protection

Requests to non-exposed paths return 404 from API Gateway:

```
GET https://api.example.com/api/v1/admin   → 404 Not Found
GET https://api.example.com/health         → 404 Not Found
```

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

- [Lesson 10: Resource Mapping](../lesson-01-aws-api-gateway/10-resource-mapping/README.md)
- [Lesson 11: Selective Path Exposure](../lesson-01-aws-api-gateway/11-selective-path-exposure/README.md)
- [AWS HTTP API VPC Link](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vpc-links.html)
