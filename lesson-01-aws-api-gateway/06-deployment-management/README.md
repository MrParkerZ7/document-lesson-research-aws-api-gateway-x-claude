# 06. Deployment and Management

## Overview

Effective deployment and management practices are essential for maintaining reliable APIs in production. This lesson covers API Gateway deployment strategies, versioning, custom domains, monitoring, and operational best practices.

## Learning Objectives

- Understand stages and deployments
- Implement version management strategies
- Configure canary deployments
- Set up custom domains with certificates
- Monitor APIs with CloudWatch and X-Ray
- Implement CI/CD pipelines for API Gateway

## 1. Stages and Deployments

### Understanding the Relationship

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Stages and Deployments                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  API Definition (Resources, Methods, Integrations)                       │
│     │                                                                    │
│     │  Deploy creates snapshot                                          │
│     ▼                                                                    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Deployment (Immutable Snapshot)                                 │    │
│  │  ID: abc123                                                      │    │
│  │  Created: 2024-01-15 10:00:00                                   │    │
│  │  Description: "Added payment endpoint"                           │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│     │                                                                    │
│     │  Associate with stages                                            │
│     ▼                                                                    │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐               │
│  │  Stage: dev   │  │  Stage: staging│  │  Stage: prod  │               │
│  │  Deployment:  │  │  Deployment:   │  │  Deployment:  │               │
│  │  abc123       │  │  xyz789        │  │  def456       │               │
│  │               │  │                │  │               │               │
│  │  URL:         │  │  URL:          │  │  URL:         │               │
│  │  .../dev      │  │  .../staging   │  │  .../prod     │               │
│  └───────────────┘  └───────────────┘  └───────────────┘               │
│                                                                          │
│  Each stage can:                                                         │
│  • Point to different deployment                                        │
│  • Have unique stage variables                                          │
│  • Have different settings (throttling, caching, logging)              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Stage Configuration Options

| Setting | Description | Per-Stage |
|---------|-------------|-----------|
| Deployment | API snapshot to use | Yes |
| Stage Variables | Environment-specific values | Yes |
| Throttling | Rate and burst limits | Yes |
| Caching | Cache capacity and TTL | Yes |
| Logging | Access logs, execution logs | Yes |
| X-Ray | Distributed tracing | Yes |
| Client Certificate | mTLS for backend | Yes |
| WAF | Web ACL association | Yes |

### Stage Variables

```yaml
# Stage variable configuration
Stages:
  dev:
    Variables:
      lambdaAlias: dev
      environment: development
      logLevel: DEBUG
      enableCache: "false"

  staging:
    Variables:
      lambdaAlias: staging
      environment: staging
      logLevel: INFO
      enableCache: "true"

  prod:
    Variables:
      lambdaAlias: prod
      environment: production
      logLevel: ERROR
      enableCache: "true"
```

### Using Stage Variables

```velocity
## In Lambda integration URI
arn:aws:lambda:region:account:function:MyFunction:${stageVariables.lambdaAlias}

## In mapping templates
#set($env = "$stageVariables.environment")
{
  "environment": "$env",
  "requestId": "$context.requestId"
}

## In HTTP endpoint
https://${stageVariables.backendHost}/api/v1/resource
```

## 2. Deployment Strategies

### Blue-Green Deployment

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Blue-Green Deployment                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Before (Blue active):                                                   │
│  ┌─────────────────┐                                                    │
│  │  Custom Domain  │                                                    │
│  │  api.example.com│                                                    │
│  └────────┬────────┘                                                    │
│           │ Base Path: /v1                                              │
│           ▼                                                              │
│  ┌─────────────────┐     ┌─────────────────┐                           │
│  │  Stage: blue    │     │  Stage: green   │                           │
│  │  (v1.0 - LIVE) │     │  (v1.1 - TEST)  │                           │
│  └─────────────────┘     └─────────────────┘                           │
│                                                                          │
│  After (Green active):                                                   │
│  ┌─────────────────┐                                                    │
│  │  Custom Domain  │                                                    │
│  │  api.example.com│                                                    │
│  └────────┬────────┘                                                    │
│           │ Base Path: /v1 (switched)                                   │
│           ▼                                                              │
│  ┌─────────────────┐     ┌─────────────────┐                           │
│  │  Stage: blue    │     │  Stage: green   │                           │
│  │  (v1.0 - OLD)   │     │  (v1.1 - LIVE) │                           │
│  └─────────────────┘     └─────────────────┘                           │
│                                                                          │
│  Rollback: Switch base path mapping back to blue                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Canary Deployment

Route a percentage of traffic to new deployment for gradual rollout.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Canary Deployment                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Stage: prod                                                             │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                                                                   │    │
│  │  Incoming Traffic (100%)                                         │    │
│  │         │                                                         │    │
│  │         ▼                                                         │    │
│  │  ┌─────────────────┐                                             │    │
│  │  │  Traffic Split  │                                             │    │
│  │  └────────┬────────┘                                             │    │
│  │           │                                                       │    │
│  │     ┌─────┴─────┐                                                │    │
│  │     │           │                                                │    │
│  │    90%         10%                                               │    │
│  │     │           │                                                │    │
│  │     ▼           ▼                                                │    │
│  │  ┌──────┐    ┌──────┐                                           │    │
│  │  │ Main │    │Canary│                                           │    │
│  │  │v1.0  │    │v1.1  │                                           │    │
│  │  └──────┘    └──────┘                                           │    │
│  │                                                                   │    │
│  │  Canary settings:                                                │    │
│  │  • percentTraffic: 10%                                          │    │
│  │  • useStageCache: false                                         │    │
│  │  • stageVariableOverrides: { lambdaAlias: "canary" }           │    │
│  │                                                                   │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Promotion: Increase canary traffic → 100% (promote)                    │
│  Rollback: Set canary traffic to 0%                                     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Canary Configuration

```yaml
CanarySettings:
  Type: AWS::ApiGateway::Stage
  Properties:
    StageName: prod
    RestApiId: !Ref MyApi
    DeploymentId: !Ref MainDeployment
    CanarySettings:
      PercentTraffic: 10
      StageVariableOverrides:
        lambdaAlias: canary
      UseStageCache: false
```

### Canary Management Commands

```bash
# Create canary deployment
aws apigateway create-deployment \
  --rest-api-id abc123 \
  --stage-name prod \
  --canary-settings percentTraffic=10

# Update canary percentage
aws apigateway update-stage \
  --rest-api-id abc123 \
  --stage-name prod \
  --patch-operations \
    op=replace,path=/canarySettings/percentTraffic,value=50

# Promote canary (100% traffic)
aws apigateway update-stage \
  --rest-api-id abc123 \
  --stage-name prod \
  --patch-operations \
    op=replace,path=/deploymentId,value=canary-deployment-id

# Delete canary (rollback)
aws apigateway update-stage \
  --rest-api-id abc123 \
  --stage-name prod \
  --patch-operations \
    op=remove,path=/canarySettings
```

## 3. Custom Domains

### Custom Domain Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Custom Domain Setup                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  DNS (Route 53)                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  api.example.com  →  ALIAS  →  d-xyz.execute-api.region.amazonaws│   │
│  └─────────────────────────────────────────────────────────────────┘    │
│                              │                                           │
│                              ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Custom Domain Name                                              │    │
│  │  Domain: api.example.com                                         │    │
│  │  Certificate: ACM certificate                                    │    │
│  │  Endpoint: Regional or Edge-optimized                           │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                              │                                           │
│                              │ Base Path Mappings                       │
│                              │                                           │
│           ┌──────────────────┼──────────────────┐                       │
│           │                  │                  │                       │
│           ▼                  ▼                  ▼                       │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │
│  │  /v1        │    │  /v2        │    │  /internal  │                 │
│  │  API: MyAPI │    │  API: MyAPI │    │  API: Admin │                 │
│  │  Stage: v1  │    │  Stage: v2  │    │  Stage: prod│                 │
│  └─────────────┘    └─────────────┘    └─────────────┘                 │
│                                                                          │
│  Result:                                                                 │
│  • api.example.com/v1/* → MyAPI v1 stage                               │
│  • api.example.com/v2/* → MyAPI v2 stage                               │
│  • api.example.com/internal/* → Admin API                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Custom Domain Configuration

```yaml
# ACM Certificate (must be in us-east-1 for edge-optimized)
Certificate:
  Type: AWS::CertificateManager::Certificate
  Properties:
    DomainName: api.example.com
    SubjectAlternativeNames:
      - "*.api.example.com"
    ValidationMethod: DNS
    DomainValidationOptions:
      - DomainName: api.example.com
        HostedZoneId: !Ref HostedZoneId

# Custom Domain Name
CustomDomain:
  Type: AWS::ApiGateway::DomainName
  Properties:
    DomainName: api.example.com
    RegionalCertificateArn: !Ref Certificate  # For regional
    # CertificateArn: !Ref Certificate        # For edge-optimized
    EndpointConfiguration:
      Types:
        - REGIONAL  # or EDGE
    SecurityPolicy: TLS_1_2

# Base Path Mapping
V1Mapping:
  Type: AWS::ApiGateway::BasePathMapping
  Properties:
    DomainName: !Ref CustomDomain
    RestApiId: !Ref MyApi
    Stage: v1
    BasePath: v1

V2Mapping:
  Type: AWS::ApiGateway::BasePathMapping
  Properties:
    DomainName: !Ref CustomDomain
    RestApiId: !Ref MyApi
    Stage: v2
    BasePath: v2

# Route 53 Record
DnsRecord:
  Type: AWS::Route53::RecordSet
  Properties:
    HostedZoneId: !Ref HostedZoneId
    Name: api.example.com
    Type: A
    AliasTarget:
      DNSName: !GetAtt CustomDomain.RegionalDomainName
      HostedZoneId: !GetAtt CustomDomain.RegionalHostedZoneId
```

### Regional vs Edge-Optimized

| Aspect | Regional | Edge-Optimized |
|--------|----------|----------------|
| Latency | Best for regional clients | Best for global clients |
| Certificate | Regional ACM | us-east-1 ACM only |
| CloudFront | Bring your own (optional) | Managed by AWS |
| Cost | Lower | Higher (CloudFront) |
| Custom headers | Full control | Limited |
| WAF | Regional WAF | CloudFront WAF |

## 4. API Versioning Strategies

### URL Path Versioning

```
┌─────────────────────────────────────────────────────────────────────────┐
│  URL Path Versioning                                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  api.example.com/v1/customers                                           │
│  api.example.com/v2/customers                                           │
│  api.example.com/v3/customers                                           │
│                                                                          │
│  Implementation options:                                                 │
│                                                                          │
│  Option 1: Multiple stages in one API                                   │
│  ┌──────────────────────────────────────────────────────┐               │
│  │  MyApi                                                │               │
│  │  ├── Stage: v1 → Deployment A                        │               │
│  │  ├── Stage: v2 → Deployment B                        │               │
│  │  └── Stage: v3 → Deployment C                        │               │
│  └──────────────────────────────────────────────────────┘               │
│                                                                          │
│  Option 2: Base path mappings                                           │
│  ┌──────────────────────────────────────────────────────┐               │
│  │  Custom Domain: api.example.com                       │               │
│  │  ├── /v1 → API-v1 (separate API)                     │               │
│  │  ├── /v2 → API-v2 (separate API)                     │               │
│  │  └── /v3 → API-v3 (separate API)                     │               │
│  └──────────────────────────────────────────────────────┘               │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Header-Based Versioning

```velocity
## Route based on Accept-Version header
#set($version = $input.params('Accept-Version'))
#if($version == "2.0")
  ## Use v2 backend
  arn:aws:lambda:region:account:function:MyFunction:v2
#else
  ## Default to v1
  arn:aws:lambda:region:account:function:MyFunction:v1
#end
```

### Query Parameter Versioning

```
GET /customers?version=2
GET /customers?api-version=2024-01-01

## Lambda can read: $input.params('version')
```

## 5. Monitoring and Logging

### CloudWatch Metrics

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    API Gateway CloudWatch Metrics                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Request Metrics                                                         │
│  ├── Count: Total number of API calls                                  │
│  ├── 4XXError: Client error count                                      │
│  ├── 5XXError: Server error count                                      │
│  └── CacheHitCount / CacheMissCount: Cache performance                 │
│                                                                          │
│  Latency Metrics                                                         │
│  ├── Latency: Total response time (client to client)                   │
│  └── IntegrationLatency: Backend response time only                    │
│                                                                          │
│  Dimensions                                                              │
│  ├── ApiName: Filter by API                                            │
│  ├── Stage: Filter by stage                                            │
│  ├── Method: Filter by HTTP method                                     │
│  └── Resource: Filter by path                                          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### CloudWatch Alarms

```yaml
# 5XX Error Rate Alarm
HighErrorRateAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: API-High-5XX-Error-Rate
    MetricName: 5XXError
    Namespace: AWS/ApiGateway
    Dimensions:
      - Name: ApiName
        Value: !Ref MyApi
      - Name: Stage
        Value: prod
    Statistic: Sum
    Period: 60
    EvaluationPeriods: 3
    Threshold: 10
    ComparisonOperator: GreaterThanThreshold
    AlarmActions:
      - !Ref AlertSNSTopic

# High Latency Alarm
HighLatencyAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: API-High-Latency
    MetricName: Latency
    Namespace: AWS/ApiGateway
    Dimensions:
      - Name: ApiName
        Value: !Ref MyApi
    ExtendedStatistic: p95
    Period: 300
    EvaluationPeriods: 2
    Threshold: 3000  # 3 seconds
    ComparisonOperator: GreaterThanThreshold
```

### Access Logging

```yaml
# Access log configuration
Stage:
  Type: AWS::ApiGateway::Stage
  Properties:
    StageName: prod
    AccessLogSetting:
      DestinationArn: !GetAtt AccessLogGroup.Arn
      Format: >-
        {
          "requestId": "$context.requestId",
          "ip": "$context.identity.sourceIp",
          "caller": "$context.identity.caller",
          "user": "$context.identity.user",
          "requestTime": "$context.requestTime",
          "httpMethod": "$context.httpMethod",
          "resourcePath": "$context.resourcePath",
          "status": "$context.status",
          "protocol": "$context.protocol",
          "responseLength": "$context.responseLength",
          "integrationLatency": "$context.integrationLatency",
          "responseLatency": "$context.responseLatency"
        }
```

### X-Ray Tracing

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    X-Ray Distributed Tracing                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Client Request                                                          │
│       │                                                                  │
│       ▼                                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  API Gateway (Trace ID: 1-abc123-def456)                        │    │
│  │  └── Segment: API Gateway                                       │    │
│  │      ├── Subsegment: Authorization (50ms)                       │    │
│  │      ├── Subsegment: Request Validation (10ms)                  │    │
│  │      └── Subsegment: Integration (200ms)                        │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│       │                                                                  │
│       ▼                                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Lambda Function                                                 │    │
│  │  └── Segment: Lambda                                             │    │
│  │      ├── Subsegment: Initialization (100ms)                     │    │
│  │      ├── Subsegment: Handler (80ms)                             │    │
│  │      │   ├── Subsegment: DynamoDB GetItem (20ms)               │    │
│  │      │   └── Subsegment: External API (40ms)                   │    │
│  │      └── Subsegment: Response (5ms)                             │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Enable: TracingEnabled: true in stage settings                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### X-Ray Configuration

```yaml
Stage:
  Type: AWS::ApiGateway::Stage
  Properties:
    StageName: prod
    TracingEnabled: true
    MethodSettings:
      - ResourcePath: "/*"
        HttpMethod: "*"
        DataTraceEnabled: true
        LoggingLevel: INFO
        MetricsEnabled: true
```

## 6. CI/CD Pipeline

### Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    API Gateway CI/CD Pipeline                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐          │
│  │  Source  │───▶│  Build   │───▶│  Test    │───▶│  Deploy  │          │
│  │          │    │          │    │          │    │          │          │
│  │ GitHub   │    │ CodeBuild│    │ CodeBuild│    │CloudForm │          │
│  │ Commit   │    │ Package  │    │ API Tests│    │   ation  │          │
│  └──────────┘    └──────────┘    └──────────┘    └────┬─────┘          │
│                                                        │                │
│                                           ┌────────────┼────────────┐   │
│                                           │            │            │   │
│                                           ▼            ▼            ▼   │
│                                      ┌────────┐  ┌────────┐  ┌────────┐ │
│                                      │  Dev   │  │Staging │  │  Prod  │ │
│                                      │        │  │        │  │ Canary │ │
│                                      └────────┘  └────────┘  └────────┘ │
│                                                        │                │
│                                                        │ Manual Approval│
│                                                        ▼                │
│                                                  ┌────────┐             │
│                                                  │  Prod  │             │
│                                                  │  100%  │             │
│                                                  └────────┘             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### SAM Pipeline Example

```yaml
# buildspec.yml
version: 0.2
phases:
  install:
    commands:
      - pip install aws-sam-cli
  build:
    commands:
      - sam build
      - sam package --output-template-file packaged.yaml --s3-bucket $ARTIFACT_BUCKET
artifacts:
  files:
    - packaged.yaml
    - template.yaml
```

```yaml
# pipeline.yaml (CodePipeline)
Pipeline:
  Type: AWS::CodePipeline::Pipeline
  Properties:
    Stages:
      - Name: Source
        Actions:
          - Name: Source
            ActionTypeId:
              Category: Source
              Provider: GitHub
            Configuration:
              Owner: !Ref GitHubOwner
              Repo: !Ref GitHubRepo
              Branch: main

      - Name: Build
        Actions:
          - Name: Build
            ActionTypeId:
              Category: Build
              Provider: CodeBuild
            Configuration:
              ProjectName: !Ref BuildProject

      - Name: DeployDev
        Actions:
          - Name: Deploy
            ActionTypeId:
              Category: Deploy
              Provider: CloudFormation
            Configuration:
              ActionMode: CREATE_UPDATE
              StackName: api-dev
              ParameterOverrides: '{"Environment": "dev"}'

      - Name: DeployProd
        Actions:
          - Name: Approval
            ActionTypeId:
              Category: Approval
              Provider: Manual
          - Name: Deploy
            ActionTypeId:
              Category: Deploy
              Provider: CloudFormation
            Configuration:
              ActionMode: CREATE_UPDATE
              StackName: api-prod
              ParameterOverrides: '{"Environment": "prod"}'
```

### API Testing in Pipeline

```python
# test_api.py
import requests
import pytest

BASE_URL = os.environ.get('API_URL')

def test_health_check():
    response = requests.get(f"{BASE_URL}/health")
    assert response.status_code == 200
    assert response.json()['status'] == 'healthy'

def test_create_customer():
    payload = {
        "name": "Test Customer",
        "email": "test@example.com"
    }
    response = requests.post(
        f"{BASE_URL}/customers",
        json=payload,
        headers={"Authorization": f"Bearer {get_test_token()}"}
    )
    assert response.status_code == 201
    assert 'id' in response.json()

def test_rate_limiting():
    # Send requests rapidly
    responses = [
        requests.get(f"{BASE_URL}/health")
        for _ in range(100)
    ]
    # Some should be throttled
    throttled = [r for r in responses if r.status_code == 429]
    assert len(throttled) > 0  # Rate limiting is working
```

## 7. OpenAPI/Swagger Integration

### Export API Definition

```bash
# Export as OpenAPI 3.0
aws apigateway get-export \
  --rest-api-id abc123 \
  --stage-name prod \
  --export-type oas30 \
  --accepts application/json \
  api-definition.json

# Export with API Gateway extensions
aws apigateway get-export \
  --rest-api-id abc123 \
  --stage-name prod \
  --export-type oas30 \
  --parameters extensions='integrations' \
  api-definition-full.json
```

### Import API from OpenAPI

```yaml
# SAM template with OpenAPI
MyApi:
  Type: AWS::Serverless::Api
  Properties:
    StageName: prod
    DefinitionBody:
      openapi: "3.0.1"
      info:
        title: My API
        version: "1.0"
      paths:
        /customers:
          get:
            x-amazon-apigateway-integration:
              type: aws_proxy
              httpMethod: POST
              uri: !Sub arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${GetCustomersFunction.Arn}/invocations
```

## Key Takeaways

1. **Use stages effectively** - Separate environments with appropriate settings
2. **Implement canary deployments** - Reduce risk with gradual rollouts
3. **Custom domains are essential** - Provide stable URLs independent of API Gateway IDs
4. **Monitor proactively** - Set up alarms for errors and latency
5. **Enable tracing** - X-Ray helps debug distributed systems
6. **Automate deployments** - CI/CD pipelines reduce human error
7. **Version your APIs** - Plan for backwards compatibility

## Further Reading

- [Deploying APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-deploy-api.html)
- [Canary Deployments](https://docs.aws.amazon.com/apigateway/latest/developerguide/canary-release.html)
- [Custom Domain Names](https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-custom-domains.html)
- [CloudWatch Metrics](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-metrics-and-dimensions.html)
