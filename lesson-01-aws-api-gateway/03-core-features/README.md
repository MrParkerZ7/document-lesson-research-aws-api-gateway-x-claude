# 03. Core Features of AWS API Gateway

## Overview

AWS API Gateway provides a rich set of features for building, securing, and managing APIs. This lesson covers the core capabilities that make API Gateway a powerful tool for modern application development.

## Learning Objectives

- Understand request/response transformations
- Configure API caching for improved performance
- Implement throttling and rate limiting
- Set up request validation
- Use models and mapping templates
- Configure CORS properly

## Core Features Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     API Gateway Core Features                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │   Request       │  │    Caching      │  │   Throttling    │         │
│  │   Validation    │  │                 │  │   & Quotas      │         │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘         │
│                                                                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │   Request/Resp  │  │      CORS       │  │    Logging &    │         │
│  │   Transformation│  │   Configuration │  │    Monitoring   │         │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘         │
│                                                                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │   Binary        │  │    Timeout      │  │    Stage        │         │
│  │   Support       │  │   Configuration │  │    Variables    │         │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 1. Request Validation

Request validation helps ensure that incoming requests meet your API's requirements before reaching your backend.

### What Can Be Validated

| Component | Validation Options |
|-----------|-------------------|
| Query Parameters | Required, data type |
| Headers | Required, data type |
| Request Body | JSON Schema validation |
| Path Parameters | Pattern matching |

### Validation Modes

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Request Validation Modes                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  validateRequestBody: true                                               │
│  ├── Validates request body against JSON Schema model                   │
│  └── Returns 400 if validation fails                                    │
│                                                                          │
│  validateRequestParameters: true                                         │
│  ├── Validates required query parameters                                │
│  ├── Validates required headers                                         │
│  └── Returns 400 if required parameters missing                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### JSON Schema Model Example

```json
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "title": "CreatePaymentRequest",
  "type": "object",
  "required": ["sourceAccount", "destinationAccount", "amount", "currency"],
  "properties": {
    "sourceAccount": {
      "type": "string",
      "pattern": "^[A-Z]{2}[0-9]{2}[A-Z0-9]{1,30}$",
      "description": "IBAN of source account"
    },
    "destinationAccount": {
      "type": "string",
      "pattern": "^[A-Z]{2}[0-9]{2}[A-Z0-9]{1,30}$",
      "description": "IBAN of destination account"
    },
    "amount": {
      "type": "number",
      "minimum": 0.01,
      "maximum": 1000000,
      "description": "Payment amount"
    },
    "currency": {
      "type": "string",
      "enum": ["USD", "EUR", "GBP", "THB"],
      "description": "ISO 4217 currency code"
    },
    "reference": {
      "type": "string",
      "maxLength": 140,
      "description": "Payment reference"
    },
    "executionDate": {
      "type": "string",
      "format": "date",
      "description": "Scheduled execution date (optional)"
    }
  },
  "additionalProperties": false
}
```

### Validation Error Response

```json
{
  "message": "Invalid request body",
  "errors": [
    {
      "field": "amount",
      "message": "must be greater than 0.01"
    },
    {
      "field": "currency",
      "message": "must be one of: USD, EUR, GBP, THB"
    }
  ]
}
```

## 2. Request/Response Transformation

Transformations allow you to modify requests before they reach your backend and responses before they're returned to clients.

### Transformation Options by API Type

| Feature | REST API | HTTP API |
|---------|----------|----------|
| VTL Templates | Yes | No |
| Parameter Mapping | Yes | Yes |
| Header Manipulation | Yes | Limited |
| Body Transformation | Yes | No |

### VTL (Velocity Template Language) Basics

```velocity
## Accessing input data
$input.path('$.fieldName')           ## JSON path
$input.params('paramName')           ## Path/query/header params
$input.body                          ## Raw request body
$context.requestId                   ## Request context

## Variables
#set($myVar = "value")
#set($items = $input.path('$.items'))

## Conditionals
#if($input.path('$.type') == "premium")
  "tier": "gold"
#else
  "tier": "standard"
#end

## Loops
#foreach($item in $items)
  {
    "id": "$item.id",
    "name": "$item.name"
  }#if($foreach.hasNext),#end
#end
```

### Integration Request Transformation Example

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Client Request                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  POST /api/v1/payments                                                   │
│  Headers: Authorization: Bearer xxx, X-Idempotency-Key: abc123          │
│  Body: {                                                                 │
│    "from": "GB82WEST12345698765432",                                    │
│    "to": "DE89370400440532013000",                                      │
│    "amount": 1000.00,                                                    │
│    "currency": "EUR"                                                     │
│  }                                                                       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  VTL Mapping Template                                                    │
├─────────────────────────────────────────────────────────────────────────┤
│  #set($inputRoot = $input.path('$'))                                    │
│  {                                                                       │
│    "TableName": "Payments",                                             │
│    "Item": {                                                            │
│      "paymentId": {"S": "$context.requestId"},                          │
│      "idempotencyKey": {"S": "$input.params('X-Idempotency-Key')"},     │
│      "sourceIban": {"S": "$inputRoot.from"},                            │
│      "destIban": {"S": "$inputRoot.to"},                                │
│      "amount": {"N": "$inputRoot.amount"},                              │
│      "currency": {"S": "$inputRoot.currency"},                          │
│      "status": {"S": "PENDING"},                                        │
│      "createdAt": {"S": "$context.requestTime"}                         │
│    }                                                                     │
│  }                                                                       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  DynamoDB PutItem Request (transformed)                                  │
└─────────────────────────────────────────────────────────────────────────┘
```

### Integration Response Transformation Example

```velocity
## Transform DynamoDB response to clean JSON
#set($inputRoot = $input.path('$'))
#if($inputRoot.Item)
{
  "paymentId": "$inputRoot.Item.paymentId.S",
  "status": "$inputRoot.Item.status.S",
  "amount": $inputRoot.Item.amount.N,
  "currency": "$inputRoot.Item.currency.S",
  "createdAt": "$inputRoot.Item.createdAt.S"
}
#else
{
  "error": "Payment not found"
}
#end
```

### Parameter Mapping (HTTP API)

HTTP APIs support simpler parameter mapping without VTL:

```yaml
# Parameter mapping expressions
$request.path.id              # Path parameter
$request.querystring.filter   # Query string
$request.header.Authorization # Header value
$context.requestId            # Context variable
$stageVariables.env           # Stage variable
```

## 3. API Caching

Caching reduces backend load and improves response times by storing responses at the API Gateway level.

### Cache Configuration

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Caching Architecture                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Client ─────▶ API Gateway ─────▶ Cache ─────▶ Backend                  │
│                     │              │                                     │
│                     │         ┌────┴────┐                               │
│                     │         │  HIT?   │                               │
│                     │         └────┬────┘                               │
│                     │          Yes │ No                                 │
│                     │              ▼                                    │
│                     │◀───── Return cached                               │
│                     │        response                                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Cache Settings

| Setting | Options | Description |
|---------|---------|-------------|
| Cache Capacity | 0.5GB - 237GB | Size of cache cluster |
| TTL | 0 - 3600 seconds | Time to live (default: 300s) |
| Per-key Cache | Enable/Disable | Cache per API key |
| Encryption | Enable/Disable | Encrypt cached data |

### Cache Key Parameters

```
Cache key composition:
┌────────────────────────────────────────────────┐
│  GET /accounts/{accountId}/transactions        │
│  ?startDate=2024-01-01&endDate=2024-01-31     │
│  Header: Accept-Language: en                   │
├────────────────────────────────────────────────┤
│  Cache Key = Method + Path + Selected Params   │
│                                                │
│  Cached by:                                    │
│  • Path parameters: accountId                  │
│  • Query strings: startDate, endDate           │
│  • Headers: Accept-Language                    │
│                                                │
│  Result: Different cache entries for:          │
│  • Different accounts                          │
│  • Different date ranges                       │
│  • Different languages                         │
└────────────────────────────────────────────────┘
```

### Cache Invalidation

```bash
# Invalidate cache via API call
curl -X DELETE \
  "https://api-id.execute-api.region.amazonaws.com/stage/path" \
  -H "Cache-Control: max-age=0"

# Flush entire stage cache (AWS CLI)
aws apigateway flush-stage-cache \
  --rest-api-id abc123 \
  --stage-name prod
```

### Caching Best Practices

| Do | Don't |
|----|-------|
| Cache GET requests | Cache POST/PUT/DELETE |
| Use appropriate TTL for data volatility | Use caching for real-time data |
| Include all varying parameters in cache key | Cache authenticated user-specific data |
| Monitor cache hit rate | Over-cache (expensive) |

## 4. Throttling and Rate Limiting

Throttling protects your backend from being overwhelmed and ensures fair usage.

### Throttling Levels

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Throttling Hierarchy                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Level 1: Account Limit (Regional)                                       │
│  └── Default: 10,000 requests/second (can request increase)            │
│                                                                          │
│  Level 2: Stage Limit                                                    │
│  └── Applied per API stage (e.g., prod: 5000 rps, dev: 100 rps)        │
│                                                                          │
│  Level 3: Route/Method Limit                                             │
│  └── Per specific endpoint (e.g., POST /payments: 100 rps)             │
│                                                                          │
│  Level 4: Usage Plan Limit                                               │
│  └── Per API key (e.g., Partner A: 1000/day, Partner B: 10000/day)     │
│                                                                          │
│  Evaluation Order: Usage Plan → Route → Stage → Account                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Throttling Configuration

| Setting | Description | Example |
|---------|-------------|---------|
| Rate | Requests per second (steady-state) | 1000 rps |
| Burst | Maximum concurrent requests | 2000 requests |
| Quota | Requests per time period | 10,000/day |

### Token Bucket Algorithm

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Token Bucket Concept                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Bucket Capacity (Burst): 500 tokens                                    │
│  Fill Rate (Rate): 100 tokens/second                                    │
│                                                                          │
│  ┌──────────────────┐                                                   │
│  │  Token Bucket    │  ← Fills at 100/sec                              │
│  │  ████████████    │                                                   │
│  │  ████████████    │  Capacity: 500                                   │
│  │  ████████████    │                                                   │
│  └────────┬─────────┘                                                   │
│           │                                                              │
│           ▼                                                              │
│     Each request consumes 1 token                                       │
│     If empty → 429 Too Many Requests                                    │
│                                                                          │
│  Scenario:                                                               │
│  • Burst of 500 requests → All processed (bucket empty)                │
│  • Next 100 requests → 429 (wait for refill)                           │
│  • After 1 second → 100 more requests allowed                          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Usage Plans and API Keys

```json
// Usage Plan Definition
{
  "name": "Partner-Gold-Plan",
  "description": "High-volume partner access",
  "throttle": {
    "rateLimit": 1000,
    "burstLimit": 2000
  },
  "quota": {
    "limit": 1000000,
    "period": "MONTH"
  },
  "apiStages": [
    {
      "apiId": "abc123xyz",
      "stage": "prod",
      "throttle": {
        "/payments/POST": {
          "rateLimit": 100,
          "burstLimit": 200
        }
      }
    }
  ]
}
```

### Throttling Response

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
Retry-After: 1
x-amzn-ErrorType: ThrottlingException

{
  "message": "Rate exceeded"
}
```

## 5. CORS Configuration

Cross-Origin Resource Sharing (CORS) enables web applications to make requests to your API from different domains.

### CORS Headers

| Header | Description | Example |
|--------|-------------|---------|
| Access-Control-Allow-Origin | Allowed origins | https://myapp.com |
| Access-Control-Allow-Methods | Allowed HTTP methods | GET, POST, PUT |
| Access-Control-Allow-Headers | Allowed request headers | Content-Type, Authorization |
| Access-Control-Max-Age | Preflight cache duration | 86400 (24 hours) |
| Access-Control-Allow-Credentials | Allow cookies | true |

### CORS Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CORS Preflight Flow                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Browser                    API Gateway                   Backend        │
│     │                           │                            │          │
│     │  1. OPTIONS /resource     │                            │          │
│     │  Origin: https://app.com  │                            │          │
│     │─────────────────────────▶│                            │          │
│     │                           │                            │          │
│     │  2. Preflight Response    │                            │          │
│     │  Access-Control-Allow-*   │                            │          │
│     │◀─────────────────────────│                            │          │
│     │                           │                            │          │
│     │  3. Actual Request        │                            │          │
│     │  POST /resource           │                            │          │
│     │─────────────────────────▶│───────────────────────────▶│          │
│     │                           │                            │          │
│     │  4. Response with CORS    │                            │          │
│     │◀─────────────────────────│◀───────────────────────────│          │
│     │                           │                            │          │
└─────────────────────────────────────────────────────────────────────────┘
```

### HTTP API CORS Configuration

```yaml
# SAM Template
HttpApi:
  Type: AWS::Serverless::HttpApi
  Properties:
    CorsConfiguration:
      AllowOrigins:
        - "https://myapp.com"
        - "https://staging.myapp.com"
      AllowMethods:
        - GET
        - POST
        - PUT
        - DELETE
        - OPTIONS
      AllowHeaders:
        - Content-Type
        - Authorization
        - X-Amz-Date
        - X-Api-Key
        - X-Amz-Security-Token
      AllowCredentials: true
      MaxAge: 86400
```

### REST API CORS (Mock Integration)

For REST APIs, you need to configure an OPTIONS method with mock integration:

```json
// OPTIONS Method Response Headers
{
  "method.response.header.Access-Control-Allow-Headers": "'Content-Type,Authorization,X-Amz-Date'",
  "method.response.header.Access-Control-Allow-Methods": "'GET,POST,PUT,DELETE,OPTIONS'",
  "method.response.header.Access-Control-Allow-Origin": "'https://myapp.com'"
}
```

## 6. Binary Data Support

API Gateway can handle binary payloads like images, PDFs, and files.

### Binary Media Types Configuration

```yaml
# Common binary media types
BinaryMediaTypes:
  - "image/png"
  - "image/jpeg"
  - "image/gif"
  - "application/pdf"
  - "application/octet-stream"
  - "multipart/form-data"
```

### Handling Binary Data

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Binary Data Flow                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Request:                                                                │
│  ┌─────────────────────────────────────────────────────┐                │
│  │ Content-Type: image/png                              │                │
│  │ Accept: image/png                                    │                │
│  │ [Binary PNG Data]                                    │                │
│  └─────────────────────────────────────────────────────┘                │
│                          │                                               │
│                          ▼                                               │
│  API Gateway converts to base64 if media type matches                   │
│                          │                                               │
│                          ▼                                               │
│  Lambda receives:                                                        │
│  {                                                                       │
│    "body": "iVBORw0KGgoAAAANSUhEUg...",  // base64 encoded             │
│    "isBase64Encoded": true                                              │
│  }                                                                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Lambda Handler for Binary

```python
import base64
import boto3

def handler(event, context):
    # Receiving binary (upload)
    if event.get('isBase64Encoded'):
        binary_data = base64.b64decode(event['body'])
        # Process binary data...

    # Returning binary (download)
    s3 = boto3.client('s3')
    response = s3.get_object(Bucket='my-bucket', Key='image.png')
    binary_data = response['Body'].read()

    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'image/png'
        },
        'body': base64.b64encode(binary_data).decode('utf-8'),
        'isBase64Encoded': True
    }
```

## 7. Timeout Configuration

### Timeout Limits

| API Type | Maximum Timeout | Default |
|----------|-----------------|---------|
| REST API | 29 seconds | 29 seconds |
| HTTP API | 30 seconds | 30 seconds |
| WebSocket | 29 seconds | 29 seconds |

### Handling Long-Running Operations

```
┌─────────────────────────────────────────────────────────────────────────┐
│                 Async Pattern for Long Operations                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. Client initiates request                                            │
│     POST /reports/generate                                              │
│                                                                          │
│  2. API Gateway → Lambda (quick response)                               │
│     - Validate request                                                  │
│     - Start Step Functions / SQS                                        │
│     - Return job ID immediately                                         │
│                                                                          │
│     Response: { "jobId": "abc123", "status": "PROCESSING" }            │
│                                                                          │
│  3. Background processing                                               │
│     Step Functions / Worker processes the job                           │
│                                                                          │
│  4. Client polls for status                                             │
│     GET /reports/abc123                                                 │
│                                                                          │
│     Response: { "jobId": "abc123", "status": "COMPLETED", "url": "..." }│
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 8. Stage Variables

Stage variables are name-value pairs that can be used to configure different behaviors per stage.

### Common Use Cases

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Stage Variables Usage                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Stage: dev                     Stage: prod                              │
│  ┌─────────────────────────┐   ┌─────────────────────────┐              │
│  │ lambdaAlias: dev        │   │ lambdaAlias: prod       │              │
│  │ dbEndpoint: dev.db.com  │   │ dbEndpoint: prod.db.com │              │
│  │ logLevel: DEBUG         │   │ logLevel: ERROR         │              │
│  │ cacheEnabled: false     │   │ cacheEnabled: true      │              │
│  └─────────────────────────┘   └─────────────────────────┘              │
│                                                                          │
│  Usage in Integration:                                                   │
│  • Lambda ARN: arn:aws:lambda:...:function:MyFunc:${stageVariables.lambdaAlias}
│  • HTTP Endpoint: https://${stageVariables.dbEndpoint}/api              │
│  • Mapping Template: #set($logLevel = "$stageVariables.logLevel")       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Key Takeaways

1. **Validation at the edge** - Validate requests before they reach your backend to reduce load
2. **Transform wisely** - Use VTL for complex transformations, but prefer backend logic for maintainability
3. **Cache strategically** - Cache improves performance but adds cost; monitor hit rates
4. **Layer throttling** - Combine account, stage, method, and API key limits for defense in depth
5. **CORS is essential** - Properly configure CORS for web applications
6. **Binary requires configuration** - Explicitly define binary media types

## Further Reading

- [Request Validation](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-method-request-validation.html)
- [Mapping Templates](https://docs.aws.amazon.com/apigateway/latest/developerguide/models-mappings.html)
- [API Caching](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-caching.html)
- [Throttling](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-request-throttling.html)
