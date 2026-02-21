# 10. Resource Mapping Deep Dive

## Overview

API Gateway resources define the URL paths of your API and map to backend integrations. This lesson provides a comprehensive look at all the ways you can connect API Gateway endpoints to various AWS services and external backends.

---

## Resource Path Structure

### Basic Path Patterns

```
/                     # Root resource
/users                # Static path
/users/{userId}       # Path with variable
/users/{userId}/orders/{orderId}   # Nested path variables
/users/{proxy+}       # Greedy path (catch-all)
```

### Path Variable Types

| Type | Example | Description |
|------|---------|-------------|
| **Simple** | `{id}` | Captures a single path segment |
| **Greedy** | `{proxy+}` | Captures all remaining path segments |

### Path Variable Constraints (REST API)

```json
{
  "pathParameters": {
    "userId": {
      "required": true
    }
  }
}
```

---

## Integration Types Overview

```
+------------------+------------------+------------------+
|   Integration    |    REST API      |    HTTP API      |
+------------------+------------------+------------------+
| Lambda Proxy     |       ✓          |       ✓          |
| Lambda Custom    |       ✓          |       ✗          |
| HTTP Proxy       |       ✓          |       ✓          |
| HTTP Custom      |       ✓          |       ✗          |
| AWS Service      |       ✓          |       ✗          |
| VPC Link         |       ✓          |       ✓          |
| Mock             |       ✓          |       ✗          |
| Private (ALB)    |       ✗          |       ✓          |
+------------------+------------------+------------------+
```

---

## 1. Lambda Integration

### Lambda Proxy Integration (Recommended)

The entire request is passed to Lambda, and Lambda controls the response.

**Request Format to Lambda:**
```json
{
  "resource": "/users/{userId}",
  "path": "/users/123",
  "httpMethod": "GET",
  "headers": {
    "Content-Type": "application/json",
    "Authorization": "Bearer token..."
  },
  "queryStringParameters": {
    "include": "orders"
  },
  "pathParameters": {
    "userId": "123"
  },
  "body": null,
  "isBase64Encoded": false,
  "requestContext": {
    "stage": "prod",
    "requestId": "abc-123",
    "identity": {
      "sourceIp": "192.168.1.1",
      "userAgent": "Mozilla/5.0..."
    }
  }
}
```

**Required Lambda Response Format:**
```json
{
  "statusCode": 200,
  "headers": {
    "Content-Type": "application/json",
    "X-Custom-Header": "value"
  },
  "body": "{\"userId\": \"123\", \"name\": \"John\"}",
  "isBase64Encoded": false
}
```

**Configuration:**
```yaml
# SAM/CloudFormation
MyFunction:
  Type: AWS::Serverless::Function
  Properties:
    Handler: index.handler
    Events:
      GetUser:
        Type: Api
        Properties:
          Path: /users/{userId}
          Method: GET
```

### Lambda Custom Integration

You control the request/response transformation using VTL templates.

**Integration Request Template (VTL):**
```velocity
#set($inputRoot = $input.path('$'))
{
  "userId": "$input.params('userId')",
  "queryParams": {
    #foreach($param in $input.params().querystring.keySet())
    "$param": "$input.params().querystring.get($param)"#if($foreach.hasNext),#end
    #end
  },
  "body": $input.json('$')
}
```

**Integration Response Template (VTL):**
```velocity
#set($inputRoot = $input.path('$'))
{
  "data": {
    "user": {
      "id": "$inputRoot.userId",
      "name": "$inputRoot.userName"
    }
  },
  "metadata": {
    "requestId": "$context.requestId"
  }
}
```

### Lambda with Alias/Version

**Using Stage Variables:**
```
arn:aws:lambda:us-east-1:123456789012:function:MyFunction:${stageVariables.lambdaAlias}
```

| Stage | Variable | Lambda Target |
|-------|----------|---------------|
| dev | `lambdaAlias=dev` | MyFunction:dev |
| staging | `lambdaAlias=staging` | MyFunction:staging |
| prod | `lambdaAlias=prod` | MyFunction:prod |

---

## 2. HTTP Integration

### HTTP Proxy Integration

Pass requests directly to an HTTP endpoint.

**Configuration:**
```yaml
# REST API
x-amazon-apigateway-integration:
  type: HTTP_PROXY
  httpMethod: ANY
  uri: https://backend.example.com/{proxy}
  passthroughBehavior: WHEN_NO_MATCH
  requestParameters:
    integration.request.path.proxy: method.request.path.proxy
```

**Path Parameter Mapping:**
```
API Path:         /api/{version}/users/{userId}
Backend Path:     https://backend.com/v{version}/users/{userId}

Mapping:
  integration.request.path.version: method.request.path.version
  integration.request.path.userId: method.request.path.userId
```

### HTTP Custom Integration

Transform requests before sending to backend.

**Request Transformation:**
```velocity
#set($inputRoot = $input.path('$'))
{
  "user_id": "$input.params('userId')",
  "action": "$input.params('action')",
  "timestamp": "$context.requestTimeEpoch"
}
```

### Endpoint Types

| Type | Description | Use Case |
|------|-------------|----------|
| **Regional** | Same region endpoint | Default, lowest latency in-region |
| **Edge-Optimized** | Via CloudFront | Global users, auto-caching |
| **Private** | VPC only | Internal services |

---

## 3. VPC Link Integration

Connect API Gateway to private resources in VPC.

### REST API VPC Link (NLB Required)

```
Internet → API Gateway → VPC Link → NLB → ECS/EC2/EKS
```

**Configuration:**
```yaml
VPCLink:
  Type: AWS::ApiGateway::VpcLink
  Properties:
    Name: my-vpc-link
    TargetArns:
      - !Ref NetworkLoadBalancer

# Integration
x-amazon-apigateway-integration:
  type: HTTP_PROXY
  httpMethod: ANY
  uri: http://nlb-internal.example.com/{proxy}
  connectionType: VPC_LINK
  connectionId: ${stageVariables.vpcLinkId}
```

### HTTP API VPC Link (More Options)

Supports ALB, NLB, and Cloud Map.

```yaml
# ALB Integration
x-amazon-apigateway-integration:
  type: HTTP_PROXY
  httpMethod: ANY
  uri: arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/my-alb/...
  connectionType: VPC_LINK
  connectionId: !Ref VpcLink

# Cloud Map Integration
x-amazon-apigateway-integration:
  type: HTTP_PROXY
  httpMethod: ANY
  uri: arn:aws:servicediscovery:us-east-1:123456789012:service/srv-xxx
  connectionType: VPC_LINK
  connectionId: !Ref VpcLink
```

### Path Variable with VPC Link

```
API:      GET /services/{serviceName}/resource/{resourceId}
Backend:  http://internal-nlb/{serviceName}/api/{resourceId}

Mapping:
  integration.request.path.serviceName: method.request.path.serviceName
  integration.request.path.resourceId: method.request.path.resourceId
```

---

## 4. AWS Service Integration

Direct integration with AWS services without Lambda.

### DynamoDB Integration

**Get Item:**
```yaml
x-amazon-apigateway-integration:
  type: AWS
  httpMethod: POST
  uri: arn:aws:apigateway:us-east-1:dynamodb:action/GetItem
  credentials: !GetAtt ApiGatewayRole.Arn
  requestTemplates:
    application/json: |
      {
        "TableName": "Users",
        "Key": {
          "userId": {
            "S": "$input.params('userId')"
          }
        }
      }
  responses:
    default:
      statusCode: 200
      responseTemplates:
        application/json: |
          #set($item = $input.path('$.Item'))
          {
            "userId": "$item.userId.S",
            "name": "$item.name.S",
            "email": "$item.email.S"
          }
```

**Query Items:**
```velocity
{
  "TableName": "Orders",
  "KeyConditionExpression": "userId = :uid",
  "ExpressionAttributeValues": {
    ":uid": {"S": "$input.params('userId')"}
  }
}
```

**Put Item:**
```velocity
#set($inputRoot = $input.path('$'))
{
  "TableName": "Users",
  "Item": {
    "userId": {"S": "$input.params('userId')"},
    "name": {"S": "$inputRoot.name"},
    "email": {"S": "$inputRoot.email"},
    "createdAt": {"S": "$context.requestTime"}
  }
}
```

### S3 Integration

**Get Object:**
```yaml
x-amazon-apigateway-integration:
  type: AWS
  httpMethod: GET
  uri: arn:aws:apigateway:us-east-1:s3:path/{bucket}/{key}
  credentials: !GetAtt ApiGatewayRole.Arn
  requestParameters:
    integration.request.path.bucket: method.request.path.bucket
    integration.request.path.key: method.request.path.key
```

**Put Object:**
```yaml
x-amazon-apigateway-integration:
  type: AWS
  httpMethod: PUT
  uri: arn:aws:apigateway:us-east-1:s3:path/{bucket}/{key}
  credentials: !GetAtt ApiGatewayRole.Arn
  requestParameters:
    integration.request.path.bucket: method.request.path.bucket
    integration.request.path.key: method.request.path.key
    integration.request.header.Content-Type: method.request.header.Content-Type
```

### SQS Integration

**Send Message:**
```yaml
x-amazon-apigateway-integration:
  type: AWS
  httpMethod: POST
  uri: arn:aws:apigateway:us-east-1:sqs:path/123456789012/MyQueue
  credentials: !GetAtt ApiGatewayRole.Arn
  requestParameters:
    integration.request.header.Content-Type: "'application/x-www-form-urlencoded'"
  requestTemplates:
    application/json: |
      Action=SendMessage&MessageBody=$util.urlEncode($input.body)
```

### SNS Integration

**Publish Message:**
```yaml
x-amazon-apigateway-integration:
  type: AWS
  httpMethod: POST
  uri: arn:aws:apigateway:us-east-1:sns:path//
  credentials: !GetAtt ApiGatewayRole.Arn
  requestParameters:
    integration.request.header.Content-Type: "'application/x-www-form-urlencoded'"
  requestTemplates:
    application/json: |
      Action=Publish&TopicArn=arn:aws:sns:us-east-1:123456789012:MyTopic&Message=$util.urlEncode($input.body)
```

### Step Functions Integration

**Start Execution:**
```yaml
x-amazon-apigateway-integration:
  type: AWS
  httpMethod: POST
  uri: arn:aws:apigateway:us-east-1:states:action/StartExecution
  credentials: !GetAtt ApiGatewayRole.Arn
  requestTemplates:
    application/json: |
      {
        "stateMachineArn": "arn:aws:states:us-east-1:123456789012:stateMachine:MyStateMachine",
        "input": "$util.escapeJavaScript($input.body)"
      }
```

---

## 5. Mock Integration

Return static responses without backend.

**Use Cases:**
- API prototyping
- CORS preflight responses
- Health check endpoints
- Default error responses

**Configuration:**
```yaml
x-amazon-apigateway-integration:
  type: MOCK
  requestTemplates:
    application/json: |
      {
        "statusCode": 200
      }
  responses:
    default:
      statusCode: 200
      responseTemplates:
        application/json: |
          {
            "message": "API is healthy",
            "timestamp": "$context.requestTime"
          }
```

**CORS Preflight:**
```yaml
options:
  x-amazon-apigateway-integration:
    type: MOCK
    requestTemplates:
      application/json: '{"statusCode": 200}'
    responses:
      default:
        statusCode: 200
        responseParameters:
          method.response.header.Access-Control-Allow-Headers: "'Content-Type,Authorization'"
          method.response.header.Access-Control-Allow-Methods: "'GET,POST,OPTIONS'"
          method.response.header.Access-Control-Allow-Origin: "'*'"
```

---

## 6. Parameter Mapping

### Request Parameter Types

| Source | Syntax | Example |
|--------|--------|---------|
| Path | `method.request.path.{name}` | `method.request.path.userId` |
| Query | `method.request.querystring.{name}` | `method.request.querystring.page` |
| Header | `method.request.header.{name}` | `method.request.header.Authorization` |
| Body | `method.request.body` | Full request body |
| Context | `context.{var}` | `context.requestId` |
| Stage Variables | `stageVariables.{name}` | `stageVariables.environment` |

### Mapping Examples

**Path to Query:**
```yaml
requestParameters:
  integration.request.querystring.id: method.request.path.userId
```

**Header Pass-through:**
```yaml
requestParameters:
  integration.request.header.X-Custom-Auth: method.request.header.Authorization
```

**Static Value:**
```yaml
requestParameters:
  integration.request.header.Content-Type: "'application/json'"
```

**Stage Variable:**
```yaml
requestParameters:
  integration.request.header.X-Environment: stageVariables.env
```

### Response Mapping

**Map Status Codes:**
```yaml
responses:
  "200":
    statusCode: 200
  "400":
    statusCode: 400
  "5\\d{2}":
    statusCode: 500
```

**Map Headers:**
```yaml
responseParameters:
  method.response.header.X-Request-Id: integration.response.header.x-amzn-requestid
  method.response.header.Cache-Control: "'max-age=3600'"
```

---

## 7. Greedy Path Variables

### Proxy Resource ({proxy+})

Captures all remaining path segments.

```
Resource: /api/{proxy+}

Matches:
  /api/users           → proxy = "users"
  /api/users/123       → proxy = "users/123"
  /api/users/123/orders → proxy = "users/123/orders"
```

**Lambda Proxy with Greedy Path:**
```yaml
Resources:
  ProxyResource:
    Type: AWS::ApiGateway::Resource
    Properties:
      ParentId: !Ref ApiRoot
      PathPart: "{proxy+}"
      RestApiId: !Ref RestApi

  ProxyMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      HttpMethod: ANY
      ResourceId: !Ref ProxyResource
      RestApiId: !Ref RestApi
      AuthorizationType: NONE
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub "arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${LambdaFunction.Arn}/invocations"
```

**HTTP Proxy with Greedy Path:**
```yaml
x-amazon-apigateway-integration:
  type: HTTP_PROXY
  httpMethod: ANY
  uri: https://backend.example.com/{proxy}
  requestParameters:
    integration.request.path.proxy: method.request.path.proxy
```

---

## 8. Common Patterns

### Multi-Version API

```
/v1/users/{userId}  → Lambda:v1
/v2/users/{userId}  → Lambda:v2
```

### Microservices Router

```
/users/{proxy+}     → Users Service (via VPC Link)
/orders/{proxy+}    → Orders Service (via VPC Link)
/payments/{proxy+}  → Payments Service (via VPC Link)
```

### Static + Dynamic

```
/                   → Mock (Welcome message)
/health             → Mock (Health check)
/docs               → S3 (Static documentation)
/api/{proxy+}       → Lambda (Dynamic API)
```

### Feature Flags with Stage Variables

```
Stage: dev
  - featureNewAuth=true
  - backendUrl=http://dev-backend

Stage: prod
  - featureNewAuth=false
  - backendUrl=http://prod-backend
```

---

## Best Practices

1. **Use Lambda Proxy** for most cases - simpler and more flexible
2. **Use AWS Service Integration** for simple CRUD to avoid Lambda costs
3. **Use VPC Links** for private backend access
4. **Use Greedy Paths** sparingly - they can make routing confusing
5. **Validate Path Variables** at the API Gateway level when possible
6. **Use Stage Variables** for environment-specific configurations
7. **Document Your Mappings** - VTL templates can become complex

---

## Related Documentation

- [01. Introduction](../01-introduction/README.md)
- [04. Integration Patterns](../04-integration-patterns/README.md)
- [06. Deployment & Stages](../06-deployment-management/README.md)
