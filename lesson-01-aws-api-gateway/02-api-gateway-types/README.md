# 02. API Gateway Types

## Overview

AWS API Gateway offers three distinct API types, each optimized for different use cases. Understanding the differences is crucial for selecting the right type for your requirements.

## Learning Objectives

- Understand the three API types: REST API, HTTP API, and WebSocket API
- Learn the feature differences between REST API and HTTP API
- Know when to use each API type
- Understand Private APIs for internal use cases

## API Types Comparison

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      AWS API GATEWAY TYPES                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐       │
│  │    REST API      │  │    HTTP API      │  │  WebSocket API   │       │
│  │                  │  │                  │  │                  │       │
│  │  Full-featured   │  │  Low-latency     │  │  Real-time       │       │
│  │  Traditional     │  │  Cost-effective  │  │  Bidirectional   │       │
│  │  Most control    │  │  Modern apps     │  │  Persistent      │       │
│  │                  │  │                  │  │                  │       │
│  │  $3.50/million   │  │  $1.00/million   │  │  $1.00/million   │       │
│  │  requests        │  │  requests        │  │  messages        │       │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘       │
│                                                                          │
│  + Private APIs (Any type deployed privately within VPC)                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## REST API (API Gateway v1)

### Characteristics

- **Original API Gateway** - Full feature set, most control
- **OpenAPI/Swagger support** - Import/export API definitions
- **Request/Response transformations** - VTL (Velocity Template Language)
- **API Key management** - Usage plans, quotas, throttling per key
- **Caching** - Built-in response caching
- **Resource policies** - Fine-grained access control

### When to Use REST API

| Use Case | Reason |
|----------|--------|
| Need request/response transformation | VTL templates available |
| API caching required | Built-in caching at edge |
| Complex validation rules | Request validation with models |
| Usage plans with API keys | Tiered API access for partners |
| Edge-optimized deployment | CloudFront integration |
| Need resource policies | Cross-account access control |

### REST API Request Flow

```
Client Request
      │
      ▼
┌─────────────────────────────────────────────────────────────┐
│                    REST API Processing                       │
├─────────────────────────────────────────────────────────────┤
│  1. Method Request                                           │
│     ├── Authorization (IAM, Cognito, Lambda, API Key)       │
│     ├── Request Validation (parameters, body, headers)      │
│     └── Model Validation (JSON Schema)                      │
│                                                              │
│  2. Integration Request                                      │
│     ├── VTL Transformation (map request)                    │
│     ├── Parameter Mapping                                   │
│     └── AWS Service Integration                             │
│                                                              │
│  3. Integration Response                                     │
│     ├── Response Status Mapping                             │
│     └── Response Selection (by regex pattern)               │
│                                                              │
│  4. Method Response                                          │
│     ├── VTL Transformation (map response)                   │
│     ├── Header Mapping                                      │
│     └── Response Models                                     │
└─────────────────────────────────────────────────────────────┘
      │
      ▼
Client Response
```

### REST API Endpoint Types

| Type | Description | Latency | Cost |
|------|-------------|---------|------|
| Edge-optimized | CloudFront distribution | Lower for global | Higher |
| Regional | Single region deployment | Lower for regional | Lower |
| Private | VPC-only access | Lowest (internal) | Standard |

### Example: REST API with VTL Transformation

```json
// Integration Request Mapping Template
#set($inputRoot = $input.path('$'))
{
  "TableName": "Customers",
  "Key": {
    "customerId": {
      "S": "$input.params('id')"
    }
  }
}

// Integration Response Mapping Template
#set($inputRoot = $input.path('$'))
{
  "customerId": "$inputRoot.Item.customerId.S",
  "name": "$inputRoot.Item.name.S",
  "email": "$inputRoot.Item.email.S",
  "status": "$inputRoot.Item.status.S"
}
```

## HTTP API (API Gateway v2)

### Characteristics

- **Simplified, faster** - Up to 60% faster than REST API
- **Lower cost** - Up to 71% cheaper than REST API
- **Auto-deploy** - Automatic deployments on changes
- **Native OIDC/OAuth 2.0** - Built-in JWT authorizers
- **CORS simplified** - Easy CORS configuration
- **Limited transformations** - No VTL, parameter mapping only

### When to Use HTTP API

| Use Case | Reason |
|----------|--------|
| Simple proxy to Lambda or HTTP | No transformation needed |
| JWT authentication (Cognito, Auth0) | Native JWT authorizer |
| Cost-sensitive workloads | 71% cheaper |
| Low-latency requirements | Better performance |
| CORS-heavy applications | Simplified CORS |
| Modern serverless apps | Auto-deploy, simpler config |

### HTTP API Request Flow

```
Client Request
      │
      ▼
┌─────────────────────────────────────────────────────────────┐
│                    HTTP API Processing                       │
├─────────────────────────────────────────────────────────────┤
│  1. Route Selection                                          │
│     └── Match path and method to route                      │
│                                                              │
│  2. Authorization                                            │
│     └── JWT Authorizer or Lambda Authorizer                 │
│                                                              │
│  3. Parameter Mapping (Simple)                               │
│     ├── Path parameters                                     │
│     ├── Query strings                                       │
│     ├── Headers                                             │
│     └── Stage variables                                     │
│                                                              │
│  4. Integration                                              │
│     └── Lambda / HTTP endpoint                              │
└─────────────────────────────────────────────────────────────┘
      │
      ▼
Client Response (Pass-through)
```

### Example: HTTP API Definition

```yaml
# SAM Template for HTTP API
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Resources:
  HttpApi:
    Type: AWS::Serverless::HttpApi
    Properties:
      StageName: prod
      CorsConfiguration:
        AllowOrigins:
          - "https://myapp.com"
        AllowMethods:
          - GET
          - POST
        AllowHeaders:
          - Authorization
          - Content-Type
      Auth:
        DefaultAuthorizer: JWTAuthorizer
        Authorizers:
          JWTAuthorizer:
            AuthorizationScopes:
              - email
            IdentitySource: $request.header.Authorization
            JwtConfiguration:
              issuer: https://cognito-idp.region.amazonaws.com/pool-id
              audience:
                - client-id

  GetCustomerFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: index.handler
      Runtime: nodejs18.x
      Events:
        GetCustomer:
          Type: HttpApi
          Properties:
            ApiId: !Ref HttpApi
            Path: /customers/{id}
            Method: GET
```

## REST API vs HTTP API Feature Comparison

| Feature | REST API | HTTP API |
|---------|----------|----------|
| **Pricing** | $3.50/million requests | $1.00/million requests |
| **Performance** | ~100ms overhead | ~40ms overhead |
| **Deployment** | Manual deployments | Auto-deploy available |
| **Request Validation** | JSON Schema validation | No |
| **Request Transformation** | VTL templates | Parameter mapping only |
| **Response Transformation** | VTL templates | No |
| **Caching** | Built-in (0.5GB - 237GB) | No (use CloudFront) |
| **API Keys** | Usage plans, quotas | No |
| **Usage Plans** | Throttling per key | No |
| **Resource Policies** | Yes | No |
| **AWS WAF** | Yes | Yes |
| **Custom Domains** | Yes | Yes |
| **mTLS** | Yes | Yes |
| **Private Endpoints** | Yes | Yes |
| **JWT Authorizer** | Via Lambda | Native support |
| **Lambda Authorizer** | Request/Token types | Request type only |
| **IAM Authorization** | Yes | Yes |
| **Cognito Authorizer** | Native | Via JWT Authorizer |
| **OpenAPI Import** | Full support | Limited support |
| **Edge-optimized** | Yes | No (Regional only) |
| **X-Ray Tracing** | Yes | Yes |
| **Access Logging** | Yes | Yes |
| **Execution Logging** | Yes | No |

### Decision Flowchart

```
                          Start
                            │
                            ▼
               ┌────────────────────────┐
               │ Need request/response  │
               │ transformation (VTL)?  │
               └────────────────────────┘
                      │           │
                    Yes          No
                      │           │
                      ▼           ▼
               ┌──────────┐  ┌────────────────────────┐
               │ REST API │  │ Need built-in caching? │
               └──────────┘  └────────────────────────┘
                                   │           │
                                 Yes          No
                                   │           │
                                   ▼           ▼
                            ┌──────────┐  ┌────────────────────────┐
                            │ REST API │  │ Need API key/usage     │
                            └──────────┘  │ plans for partners?    │
                                          └────────────────────────┘
                                                │           │
                                              Yes          No
                                                │           │
                                                ▼           ▼
                                         ┌──────────┐  ┌──────────┐
                                         │ REST API │  │ HTTP API │
                                         └──────────┘  └──────────┘
```

## WebSocket API

### Characteristics

- **Bidirectional communication** - Server can push to clients
- **Persistent connections** - Long-lived connections
- **Connection management** - $connect, $disconnect, $default routes
- **Message routing** - Route based on message content
- **Stateful** - Connection IDs for targeting specific clients

### When to Use WebSocket API

| Use Case | Example |
|----------|---------|
| Real-time notifications | Banking transaction alerts |
| Chat applications | Customer support chat |
| Live dashboards | Trading platform updates |
| Multiplayer games | Real-time game state sync |
| Collaborative editing | Shared document editing |
| IoT device communication | Device telemetry streams |

### WebSocket API Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        WebSocket API Flow                               │
└────────────────────────────────────────────────────────────────────────┘

  Client                    API Gateway                    Backend
    │                           │                              │
    │  1. WebSocket Upgrade     │                              │
    │──────────────────────────▶│                              │
    │                           │  $connect route              │
    │                           │─────────────────────────────▶│
    │                           │  Store connectionId          │
    │                           │◀─────────────────────────────│
    │  Connection Established   │                              │
    │◀─────────────────────────▶│                              │
    │                           │                              │
    │  2. Send Message          │                              │
    │──────────────────────────▶│                              │
    │                           │  Route: sendMessage          │
    │                           │─────────────────────────────▶│
    │                           │  Process & broadcast         │
    │                           │◀─────────────────────────────│
    │                           │                              │
    │  3. Server Push           │                              │
    │                           │  @connections/{connId}       │
    │                           │◀─────────────────────────────│
    │◀──────────────────────────│                              │
    │                           │                              │
    │  4. Disconnect            │                              │
    │──────────────────────────▶│                              │
    │                           │  $disconnect route           │
    │                           │─────────────────────────────▶│
    │                           │  Remove connectionId         │
    │                           │◀─────────────────────────────│
    │                           │                              │
```

### WebSocket Routes

| Route | Trigger | Use Case |
|-------|---------|----------|
| $connect | Client connects | Authenticate, store connection |
| $disconnect | Client disconnects | Clean up, remove connection |
| $default | Unknown route key | Fallback handler |
| Custom routes | Based on action field | sendMessage, subscribe, etc. |

### Example: WebSocket API Implementation

```python
# Lambda handler for WebSocket routes
import boto3
import json

dynamodb = boto3.resource('dynamodb')
connections_table = dynamodb.Table('WebSocketConnections')
api_gateway = boto3.client('apigatewaymanagementapi',
    endpoint_url='https://abc123.execute-api.region.amazonaws.com/prod')

def connect_handler(event, context):
    """Handle $connect route"""
    connection_id = event['requestContext']['connectionId']
    user_id = event['requestContext']['authorizer']['userId']

    connections_table.put_item(Item={
        'connectionId': connection_id,
        'userId': user_id,
        'connectedAt': event['requestContext']['connectedAt']
    })

    return {'statusCode': 200}

def disconnect_handler(event, context):
    """Handle $disconnect route"""
    connection_id = event['requestContext']['connectionId']

    connections_table.delete_item(Key={
        'connectionId': connection_id
    })

    return {'statusCode': 200}

def send_message_handler(event, context):
    """Handle custom sendMessage route"""
    connection_id = event['requestContext']['connectionId']
    body = json.loads(event['body'])
    message = body['message']
    target_user = body.get('targetUser')

    # Get target connections
    if target_user:
        connections = connections_table.query(
            IndexName='userId-index',
            KeyConditionExpression='userId = :uid',
            ExpressionAttributeValues={':uid': target_user}
        )['Items']
    else:
        connections = connections_table.scan()['Items']

    # Broadcast message
    for conn in connections:
        try:
            api_gateway.post_to_connection(
                ConnectionId=conn['connectionId'],
                Data=json.dumps({
                    'type': 'message',
                    'from': connection_id,
                    'content': message
                })
            )
        except api_gateway.exceptions.GoneException:
            # Connection is stale, clean up
            connections_table.delete_item(Key={
                'connectionId': conn['connectionId']
            })

    return {'statusCode': 200}
```

### WebSocket Pricing

| Component | Price |
|-----------|-------|
| Connection minutes | $0.25 per million |
| Messages (32KB chunks) | $1.00 per million |

**Example cost calculation:**
- 10,000 concurrent users
- 8 hours/day average connection
- 100 messages/user/day
- Monthly: 10,000 × 8 × 60 × 30 = 144M connection minutes = $36
- Monthly: 10,000 × 100 × 30 = 30M messages = $30
- **Total: ~$66/month**

## Private APIs

Private APIs are only accessible from within your VPC using VPC Endpoints.

### When to Use Private APIs

| Use Case | Reason |
|----------|--------|
| Internal microservices | Service-to-service communication |
| Backend for frontend (BFF) | Mobile/web backends in VPC |
| Regulatory compliance | No public internet exposure |
| Internal tools | Admin dashboards, monitoring |

### Private API Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              VPC                                         │
│                                                                          │
│  ┌─────────────┐     ┌──────────────────┐     ┌─────────────────────┐  │
│  │   Client    │     │   VPC Endpoint   │     │   Private API       │  │
│  │  (EC2/ECS)  │────▶│  (Interface)     │────▶│   Gateway           │  │
│  │             │     │  execute-api     │     │                     │  │
│  └─────────────┘     └──────────────────┘     └─────────────────────┘  │
│                                                         │               │
│                                                         ▼               │
│                                               ┌─────────────────────┐  │
│                                               │  Lambda / Backend   │  │
│                                               └─────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ╳ No Internet Access
                                    │
```

### Private API Resource Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "execute-api:Invoke",
      "Resource": "arn:aws:execute-api:region:account:api-id/*",
      "Condition": {
        "StringNotEquals": {
          "aws:sourceVpce": "vpce-0abc123def456"
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "execute-api:Invoke",
      "Resource": "arn:aws:execute-api:region:account:api-id/*"
    }
  ]
}
```

## Summary: Choosing the Right API Type

| Requirement | Recommended Type |
|-------------|------------------|
| Full control, transformations | REST API |
| Simple proxy, low cost | HTTP API |
| Real-time bidirectional | WebSocket API |
| Internal services only | Private API (any type) |
| Native JWT auth | HTTP API |
| API keys with usage plans | REST API |
| Edge caching | REST API (Edge-optimized) |
| Fastest performance | HTTP API |

## Key Takeaways

1. **HTTP API for most new projects** - Lower cost, better performance, simpler configuration
2. **REST API when you need full control** - Transformations, caching, usage plans
3. **WebSocket for real-time** - Chat, notifications, live dashboards
4. **Private APIs for internal** - VPC-only access for microservices
5. **Consider migration** - Existing REST APIs can often move to HTTP API for savings

## Further Reading

- [Choosing between REST API and HTTP API](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html)
- [Working with WebSocket APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-websocket-api.html)
- [Creating Private APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-private-apis.html)
