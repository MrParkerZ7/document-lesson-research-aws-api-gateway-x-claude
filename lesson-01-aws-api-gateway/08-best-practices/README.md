# 08. Best Practices

## Overview

This lesson covers production-ready best practices for designing, implementing, and operating AWS API Gateway. Following these guidelines helps ensure your APIs are secure, performant, cost-effective, and maintainable.

## Learning Objectives

- Apply API design best practices
- Optimize performance and reduce latency
- Implement cost optimization strategies
- Set up proper error handling
- Establish operational excellence patterns

## 1. API Design Best Practices

### RESTful Design Principles

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    RESTful API Design Guidelines                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Resource Naming                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  DO:                                                             │    │
│  │  • /customers                     (plural nouns)                │    │
│  │  • /customers/{id}                (resource identifier)         │    │
│  │  • /customers/{id}/orders         (sub-resources)               │    │
│  │  • /customers/{id}/orders/{orderId}                             │    │
│  │                                                                   │    │
│  │  DON'T:                                                          │    │
│  │  • /getCustomers                  (verbs in URL)                │    │
│  │  • /customer                      (singular)                    │    │
│  │  • /customers/getById             (action in path)              │    │
│  │  • /customers_list                (underscores)                 │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  HTTP Methods                                                            │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  GET     - Retrieve resource(s), idempotent, cacheable          │    │
│  │  POST    - Create new resource, not idempotent                  │    │
│  │  PUT     - Replace entire resource, idempotent                  │    │
│  │  PATCH   - Partial update, idempotent                           │    │
│  │  DELETE  - Remove resource, idempotent                          │    │
│  │  OPTIONS - CORS preflight                                        │    │
│  │  HEAD    - Same as GET without body                              │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Status Codes                                                            │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  200 OK          - Successful GET/PUT/PATCH                     │    │
│  │  201 Created     - Successful POST (include Location header)   │    │
│  │  204 No Content  - Successful DELETE                            │    │
│  │  400 Bad Request - Invalid input                                 │    │
│  │  401 Unauthorized- Missing/invalid authentication              │    │
│  │  403 Forbidden   - Authenticated but not authorized            │    │
│  │  404 Not Found   - Resource doesn't exist                       │    │
│  │  409 Conflict    - Business rule violation                      │    │
│  │  422 Unprocessable- Validation error                            │    │
│  │  429 Too Many    - Rate limit exceeded                          │    │
│  │  500 Internal    - Server error                                  │    │
│  │  503 Unavailable - Service temporarily down                     │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Versioning Strategy

```yaml
# URL Path Versioning (Recommended)
/v1/customers
/v2/customers

# Benefits:
# - Clear and visible
# - Easy to route
# - Cache-friendly

# Implementation with base path mapping:
CustomDomain:
  Mappings:
    - BasePath: v1
      Stage: production-v1
    - BasePath: v2
      Stage: production-v2
```

### Pagination Pattern

```json
// Request
GET /customers?limit=20&cursor=eyJpZCI6MTAwfQ

// Response
{
  "data": [
    {"id": "101", "name": "Customer A"},
    {"id": "102", "name": "Customer B"}
  ],
  "pagination": {
    "limit": 20,
    "hasMore": true,
    "nextCursor": "eyJpZCI6MTIwfQ",
    "totalCount": 1500
  },
  "links": {
    "self": "/customers?limit=20&cursor=eyJpZCI6MTAwfQ",
    "next": "/customers?limit=20&cursor=eyJpZCI6MTIwfQ",
    "first": "/customers?limit=20"
  }
}
```

### Error Response Format

```json
// Consistent error structure
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format",
        "value": "invalid-email"
      },
      {
        "field": "amount",
        "message": "Amount must be positive",
        "value": -100
      }
    ],
    "requestId": "abc-123-def",
    "timestamp": "2024-01-15T10:30:00Z",
    "documentation": "https://api.example.com/docs/errors#VALIDATION_ERROR"
  }
}
```

## 2. Performance Optimization

### Reducing Latency

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Latency Optimization Strategies                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. Choose HTTP API over REST API (when features allow)                 │
│     • 40-60% lower latency                                              │
│     • 71% cost savings                                                  │
│                                                                          │
│  2. Use Regional endpoints (unless global audience)                     │
│     • No CloudFront hop for regional clients                           │
│     • Lower latency for same-region                                    │
│                                                                          │
│  3. Enable caching strategically                                        │
│     • Cache GET responses for stable data                              │
│     • Use appropriate TTL (balance freshness vs performance)           │
│     • Cache key: include all varying parameters                        │
│                                                                          │
│  4. Lambda optimization                                                  │
│     • Use Provisioned Concurrency for critical paths                   │
│     • Keep Lambda warm with scheduled pings                            │
│     • Minimize package size for faster cold starts                     │
│     • Use Lambda SnapStart (Java)                                      │
│                                                                          │
│  5. Backend optimization                                                 │
│     • Use connection pooling                                            │
│     • Enable HTTP keep-alive                                            │
│     • Place backends close to API Gateway                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Caching Strategy

```yaml
# Cache configuration best practices
CacheSettings:
  CacheClusterEnabled: true
  CacheClusterSize: "0.5"  # Start small, scale as needed
  CacheTtlInSeconds: 300   # 5 minutes default

MethodSettings:
  # Cache only GET methods
  - HttpMethod: GET
    CachingEnabled: true
    CacheTtlInSeconds: 300

  # Don't cache mutations
  - HttpMethod: POST
    CachingEnabled: false
  - HttpMethod: PUT
    CachingEnabled: false
  - HttpMethod: DELETE
    CachingEnabled: false

# Cache key parameters
CacheKeyParameters:
  - method.request.path.id
  - method.request.querystring.version
  - method.request.header.Accept-Language
```

### Payload Optimization

```python
# Compress responses
def handler(event, context):
    import gzip
    import base64

    data = get_large_data()
    json_data = json.dumps(data)

    # Check if client accepts gzip
    accept_encoding = event.get('headers', {}).get('Accept-Encoding', '')

    if 'gzip' in accept_encoding:
        compressed = gzip.compress(json_data.encode('utf-8'))
        return {
            'statusCode': 200,
            'headers': {
                'Content-Encoding': 'gzip',
                'Content-Type': 'application/json'
            },
            'body': base64.b64encode(compressed).decode('utf-8'),
            'isBase64Encoded': True
        }

    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json_data
    }
```

## 3. Cost Optimization

### Cost Reduction Strategies

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Cost Optimization Techniques                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. Use HTTP API instead of REST API                                    │
│     REST: $3.50/million requests                                        │
│     HTTP: $1.00/million requests                                        │
│     Savings: Up to 71%                                                  │
│                                                                          │
│  2. Implement caching (REST API)                                        │
│     • Cache reduces backend calls                                       │
│     • Reduces Lambda invocations                                        │
│     • Cache cost vs Lambda cost (calculate breakeven)                  │
│                                                                          │
│  3. Use AWS service integrations                                        │
│     • Direct DynamoDB integration vs Lambda                            │
│     • No Lambda cost for simple operations                             │
│     Example: GET from DynamoDB                                          │
│     Lambda: $0.20/million + $0.0000166667/GB-second                    │
│     Direct: $0 (only API Gateway cost)                                 │
│                                                                          │
│  4. Optimize request/response size                                      │
│     • Data transfer charges apply                                       │
│     • Return only needed fields                                        │
│     • Use pagination with appropriate limits                           │
│                                                                          │
│  5. Right-size caching                                                   │
│     • Monitor cache hit rate                                            │
│     • Don't pay for unused cache                                        │
│     • Consider CloudFront for edge caching instead                     │
│                                                                          │
│  6. Review throttling settings                                          │
│     • Don't over-provision burst capacity                              │
│     • Set realistic limits                                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Cost Monitoring

```yaml
# CloudWatch billing alarm
BillingAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: APIGateway-MonthlyBudget
    MetricName: EstimatedCharges
    Namespace: AWS/Billing
    Dimensions:
      - Name: ServiceName
        Value: AmazonApiGateway
    Statistic: Maximum
    Period: 86400  # Daily
    EvaluationPeriods: 1
    Threshold: 1000  # $1000 threshold
    ComparisonOperator: GreaterThanThreshold
    AlarmActions:
      - !Ref AlertSNSTopic
```

## 4. Security Best Practices

### Defense in Depth

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Security Best Practices                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Layer 1: Network                                                        │
│  ├── Use HTTPS only (TLS 1.2+)                                         │
│  ├── Enable mTLS for B2B                                               │
│  ├── Use private endpoints for internal APIs                           │
│  └── Configure VPC endpoints properly                                  │
│                                                                          │
│  Layer 2: Edge Protection                                                │
│  ├── Enable AWS WAF with managed rules                                 │
│  ├── Configure rate limiting                                           │
│  ├── Block suspicious patterns                                         │
│  └── Geo-restrict if applicable                                        │
│                                                                          │
│  Layer 3: Authentication                                                 │
│  ├── Use short-lived tokens (15 min - 1 hour)                         │
│  ├── Implement token refresh mechanism                                 │
│  ├── Use strong algorithms (RS256, ES256)                             │
│  └── Validate all claims (iss, aud, exp)                              │
│                                                                          │
│  Layer 4: Authorization                                                  │
│  ├── Implement least privilege                                         │
│  ├── Use fine-grained permissions                                      │
│  ├── Validate resource ownership                                       │
│  └── Log all authorization decisions                                   │
│                                                                          │
│  Layer 5: Input Validation                                               │
│  ├── Enable request validation                                         │
│  ├── Define strict JSON schemas                                        │
│  ├── Validate path and query parameters                                │
│  └── Sanitize all inputs in backend                                   │
│                                                                          │
│  Layer 6: Logging & Monitoring                                          │
│  ├── Enable access logging                                             │
│  ├── Enable CloudTrail for API changes                                │
│  ├── Mask sensitive data in logs                                       │
│  └── Set up security alerts                                            │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Sensitive Data Handling

```python
# Never log sensitive data
def handler(event, context):
    # Mask sensitive data before logging
    safe_event = mask_sensitive_data(event)
    logger.info(f"Request received: {safe_event}")

def mask_sensitive_data(event):
    import copy
    masked = copy.deepcopy(event)

    # Mask authorization header
    if 'headers' in masked:
        if 'Authorization' in masked['headers']:
            masked['headers']['Authorization'] = '***REDACTED***'
        if 'x-api-key' in masked['headers']:
            masked['headers']['x-api-key'] = '***REDACTED***'

    # Mask sensitive body fields
    if 'body' in masked and masked['body']:
        try:
            body = json.loads(masked['body'])
            sensitive_fields = ['password', 'ssn', 'creditCard', 'accountNumber']
            for field in sensitive_fields:
                if field in body:
                    body[field] = '***REDACTED***'
            masked['body'] = json.dumps(body)
        except:
            pass

    return masked
```

## 5. Error Handling Best Practices

### Gateway Response Customization

```yaml
# Custom gateway responses
GatewayResponses:
  # Unauthorized (401)
  UNAUTHORIZED:
    StatusCode: 401
    ResponseTemplates:
      application/json: |
        {
          "error": {
            "code": "UNAUTHORIZED",
            "message": "Authentication required",
            "requestId": "$context.requestId"
          }
        }
    ResponseParameters:
      gatewayresponse.header.WWW-Authenticate: "'Bearer'"

  # Forbidden (403)
  ACCESS_DENIED:
    StatusCode: 403
    ResponseTemplates:
      application/json: |
        {
          "error": {
            "code": "FORBIDDEN",
            "message": "Access denied",
            "requestId": "$context.requestId"
          }
        }

  # Rate Limited (429)
  THROTTLED:
    StatusCode: 429
    ResponseTemplates:
      application/json: |
        {
          "error": {
            "code": "RATE_LIMITED",
            "message": "Too many requests",
            "retryAfter": 60,
            "requestId": "$context.requestId"
          }
        }
    ResponseParameters:
      gatewayresponse.header.Retry-After: "'60'"

  # Server Error (500)
  DEFAULT_5XX:
    StatusCode: 500
    ResponseTemplates:
      application/json: |
        {
          "error": {
            "code": "INTERNAL_ERROR",
            "message": "An unexpected error occurred",
            "requestId": "$context.requestId"
          }
        }
```

### Lambda Error Handling

```python
import json
from functools import wraps

class APIError(Exception):
    def __init__(self, status_code, code, message, details=None):
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details or []

def api_handler(func):
    @wraps(func)
    def wrapper(event, context):
        try:
            result = func(event, context)
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'X-Request-Id': context.aws_request_id
                },
                'body': json.dumps(result)
            }
        except APIError as e:
            return {
                'statusCode': e.status_code,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': {
                        'code': e.code,
                        'message': e.message,
                        'details': e.details,
                        'requestId': context.aws_request_id
                    }
                })
            }
        except Exception as e:
            # Log the actual error
            print(f"Unhandled error: {str(e)}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': {
                        'code': 'INTERNAL_ERROR',
                        'message': 'An unexpected error occurred',
                        'requestId': context.aws_request_id
                    }
                })
            }
    return wrapper

@api_handler
def handler(event, context):
    customer_id = event['pathParameters']['id']

    customer = get_customer(customer_id)
    if not customer:
        raise APIError(404, 'NOT_FOUND', f'Customer {customer_id} not found')

    return customer
```

## 6. Operational Excellence

### Infrastructure as Code

```yaml
# SAM template with best practices
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Parameters:
  Environment:
    Type: String
    AllowedValues: [dev, staging, prod]
  LogRetentionDays:
    Type: Number
    Default: 30

Globals:
  Api:
    OpenApiVersion: '3.0.1'
    EndpointConfiguration: REGIONAL
    TracingEnabled: true
    AccessLogSetting:
      DestinationArn: !GetAtt AccessLogGroup.Arn
      Format: '$context.requestId $context.httpMethod $context.path $context.status'
    MethodSettings:
      - ResourcePath: "/*"
        HttpMethod: "*"
        MetricsEnabled: true
        DataTraceEnabled: !If [IsDev, true, false]
        LoggingLevel: !If [IsDev, INFO, ERROR]
        ThrottlingBurstLimit: 5000
        ThrottlingRateLimit: 10000

  Function:
    Timeout: 29
    MemorySize: 256
    Runtime: python3.11
    Tracing: Active
    Environment:
      Variables:
        ENVIRONMENT: !Ref Environment
        LOG_LEVEL: !If [IsDev, DEBUG, INFO]

Conditions:
  IsDev: !Equals [!Ref Environment, dev]
  IsProd: !Equals [!Ref Environment, prod]

Resources:
  MyApi:
    Type: AWS::Serverless::HttpApi
    Properties:
      StageName: !Ref Environment
      # ... rest of configuration
```

### Monitoring Dashboard

```yaml
# CloudWatch dashboard
Dashboard:
  Type: AWS::CloudWatch::Dashboard
  Properties:
    DashboardName: !Sub "${AWS::StackName}-api-dashboard"
    DashboardBody: !Sub |
      {
        "widgets": [
          {
            "type": "metric",
            "properties": {
              "title": "API Requests",
              "metrics": [
                ["AWS/ApiGateway", "Count", "ApiName", "${MyApi}"]
              ],
              "period": 60,
              "stat": "Sum"
            }
          },
          {
            "type": "metric",
            "properties": {
              "title": "Error Rates",
              "metrics": [
                ["AWS/ApiGateway", "4XXError", "ApiName", "${MyApi}"],
                ["AWS/ApiGateway", "5XXError", "ApiName", "${MyApi}"]
              ],
              "period": 60,
              "stat": "Sum"
            }
          },
          {
            "type": "metric",
            "properties": {
              "title": "Latency (p50, p90, p99)",
              "metrics": [
                ["AWS/ApiGateway", "Latency", "ApiName", "${MyApi}", {"stat": "p50"}],
                ["...", {"stat": "p90"}],
                ["...", {"stat": "p99"}]
              ],
              "period": 60
            }
          }
        ]
      }
```

### Runbook Template

```markdown
## API Gateway Incident Runbook

### High Error Rate (5XX)

1. **Check CloudWatch Logs**
   - Access execution logs for error details
   - Look for Lambda errors, timeout issues

2. **Check Lambda Health**
   - Verify Lambda function is not throttled
   - Check for Lambda errors in X-Ray

3. **Check Backend Health**
   - Verify backend services are responding
   - Check VPC Link connectivity

4. **Mitigation Steps**
   - Increase Lambda concurrency if throttled
   - Rollback to previous deployment if recent change
   - Enable fallback response if backend is down

### High Latency

1. **Check Integration Latency**
   - Compare IntegrationLatency vs Latency
   - Identify if delay is in API Gateway or backend

2. **Check Lambda Cold Starts**
   - Look for init duration in logs
   - Consider Provisioned Concurrency

3. **Check Cache Hit Rate**
   - Low hit rate may indicate cache key issues
   - Consider increasing cache TTL

### Rate Limiting (429)

1. **Identify Source**
   - Check if specific API key or IP
   - Review usage patterns

2. **Actions**
   - Increase throttle limits if legitimate
   - Block abusive clients via WAF
   - Contact customer if partner API
```

## Key Takeaways

1. **Design for consumers** - RESTful, consistent, well-documented
2. **Optimize for performance** - Cache, compress, minimize
3. **Control costs** - Use HTTP API, avoid over-provisioning
4. **Security in layers** - Authentication, authorization, WAF, validation
5. **Handle errors gracefully** - Consistent format, helpful messages
6. **Automate everything** - IaC, CI/CD, monitoring

## Further Reading

- [AWS Well-Architected Framework - Serverless](https://docs.aws.amazon.com/wellarchitected/latest/serverless-applications-lens/)
- [API Gateway Best Practices](https://docs.aws.amazon.com/apigateway/latest/developerguide/best-practices.html)
- [REST API Design Best Practices](https://swagger.io/resources/articles/best-practices-in-api-design/)
