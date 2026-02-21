# 04. Integration Patterns

## Overview

AWS API Gateway supports multiple integration types, allowing you to connect APIs to various backend services. This lesson covers the different integration patterns, their use cases, and implementation details.

## Learning Objectives

- Understand all integration types available in API Gateway
- Implement Lambda integrations (proxy and non-proxy)
- Configure HTTP integrations for existing APIs
- Set up direct AWS service integrations
- Use VPC Links for private resources
- Implement mock integrations for testing

## Integration Types Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      API Gateway Integration Types                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    Lambda Integration                            │    │
│  │  ┌─────────────────┐        ┌─────────────────┐                 │    │
│  │  │  Lambda Proxy   │        │  Lambda Custom  │                 │    │
│  │  │  (recommended)  │        │  (with mapping) │                 │    │
│  │  └─────────────────┘        └─────────────────┘                 │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    HTTP Integration                              │    │
│  │  ┌─────────────────┐        ┌─────────────────┐                 │    │
│  │  │  HTTP Proxy     │        │  HTTP Custom    │                 │    │
│  │  │  (pass-through) │        │  (with mapping) │                 │    │
│  │  └─────────────────┘        └─────────────────┘                 │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    AWS Service Integration                       │    │
│  │  Direct integration with 100+ AWS services                      │    │
│  │  (DynamoDB, S3, SQS, SNS, Step Functions, Kinesis, etc.)       │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    VPC Link Integration                          │    │
│  │  Connect to private resources (NLB, ALB, Cloud Map)             │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    Mock Integration                              │    │
│  │  Return static responses without backend                         │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 1. Lambda Integration

The most common integration type for serverless applications.

### Lambda Proxy Integration (Recommended)

In proxy integration, API Gateway passes the entire request to Lambda and returns the Lambda response directly.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                   Lambda Proxy Integration Flow                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Client Request                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ POST /customers                                                  │    │
│  │ Headers: Authorization: Bearer xxx, Content-Type: application/json │  │
│  │ Body: {"name": "John", "email": "john@example.com"}             │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                              │                                           │
│                              ▼                                           │
│  Lambda Event (automatic conversion)                                     │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ {                                                                │    │
│  │   "resource": "/customers",                                      │    │
│  │   "path": "/customers",                                          │    │
│  │   "httpMethod": "POST",                                          │    │
│  │   "headers": {                                                   │    │
│  │     "Authorization": "Bearer xxx",                               │    │
│  │     "Content-Type": "application/json"                           │    │
│  │   },                                                             │    │
│  │   "queryStringParameters": null,                                 │    │
│  │   "pathParameters": null,                                        │    │
│  │   "body": "{\"name\": \"John\", \"email\": \"john@example.com\"}",│   │
│  │   "isBase64Encoded": false,                                      │    │
│  │   "requestContext": {                                            │    │
│  │     "requestId": "abc123",                                       │    │
│  │     "authorizer": { ... },                                       │    │
│  │     "identity": { ... }                                          │    │
│  │   }                                                              │    │
│  │ }                                                                │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Lambda Proxy Response Format

```python
def handler(event, context):
    # Process request
    customer_id = create_customer(event)

    # Must return this exact structure
    return {
        "statusCode": 201,
        "headers": {
            "Content-Type": "application/json",
            "Location": f"/customers/{customer_id}",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps({
            "id": customer_id,
            "message": "Customer created successfully"
        }),
        "isBase64Encoded": False  # Optional
    }
```

### Lambda Custom (Non-Proxy) Integration

For more control over request/response transformation using VTL templates.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                 Lambda Custom Integration Flow                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Client Request ──▶ Method Request ──▶ Integration Request ──▶ Lambda  │
│                     (validation)       (VTL transformation)             │
│                                                                          │
│  Lambda Response ──▶ Integration Response ──▶ Method Response ──▶ Client│
│                      (VTL transformation)    (headers/status)           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Example: Lambda Custom Integration

```velocity
## Integration Request Template
## Transform REST request to Lambda input
{
  "customerId": "$input.params('id')",
  "action": "GET_CUSTOMER",
  "requestedFields": [
    #foreach($field in $input.params('fields').split(','))
      "$field"#if($foreach.hasNext),#end
    #end
  ]
}
```

```velocity
## Integration Response Template
## Transform Lambda output to REST response
#set($customer = $input.path('$'))
{
  "data": {
    "id": "$customer.id",
    "name": "$customer.name",
    "email": "$customer.email"
  },
  "links": {
    "self": "/customers/$customer.id",
    "accounts": "/customers/$customer.id/accounts"
  }
}
```

### Lambda Integration Comparison

| Feature | Proxy Integration | Custom Integration |
|---------|------------------|-------------------|
| Setup complexity | Simple | Complex |
| Request transformation | In Lambda code | VTL templates |
| Response transformation | In Lambda code | VTL templates |
| Response format | Fixed structure required | Flexible |
| Error handling | In Lambda code | VTL + Gateway response |
| Use case | Most applications | Legacy systems, complex mapping |

## 2. HTTP Integration

Connect API Gateway to any HTTP endpoint.

### HTTP Proxy Integration

Passes requests directly to the backend HTTP endpoint.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    HTTP Proxy Integration                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Client                API Gateway              Backend Service          │
│    │                       │                         │                   │
│    │  GET /products/123    │                         │                   │
│    │──────────────────────▶│                         │                   │
│    │                       │  GET /api/products/123  │                   │
│    │                       │────────────────────────▶│                   │
│    │                       │                         │                   │
│    │                       │  200 OK + product data  │                   │
│    │                       │◀────────────────────────│                   │
│    │  200 OK + product     │                         │                   │
│    │◀──────────────────────│                         │                   │
│    │                       │                         │                   │
│                                                                          │
│  Configuration:                                                          │
│  • Endpoint URL: https://backend.example.com/api/{proxy}                │
│  • Method: ANY                                                           │
│  • Path: /{proxy+}                                                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### HTTP Integration Configuration

```yaml
# SAM Template for HTTP Integration
Resources:
  MyApi:
    Type: AWS::Serverless::Api
    Properties:
      StageName: prod
      DefinitionBody:
        openapi: "3.0.1"
        paths:
          /products/{id}:
            get:
              x-amazon-apigateway-integration:
                type: http_proxy
                httpMethod: GET
                uri: https://backend.example.com/api/products/{id}
                requestParameters:
                  integration.request.path.id: method.request.path.id
                  integration.request.header.X-Api-Key: "'internal-api-key'"
                passthroughBehavior: when_no_match
                timeoutInMillis: 10000
```

### HTTP Custom Integration

Transform requests before forwarding to backend.

```velocity
## Transform API Gateway request to legacy SOAP service
#set($inputRoot = $input.path('$'))
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <GetCustomer xmlns="http://legacy.bank.com/customer">
      <CustomerId>$input.params('id')</CustomerId>
    </GetCustomer>
  </soap:Body>
</soap:Envelope>
```

## 3. AWS Service Integration

Direct integration with AWS services without Lambda.

### Supported Services

| Service | Common Operations |
|---------|-------------------|
| DynamoDB | GetItem, PutItem, Query, Scan, UpdateItem, DeleteItem |
| S3 | GetObject, PutObject, DeleteObject, ListObjects |
| SQS | SendMessage, ReceiveMessage, DeleteMessage |
| SNS | Publish |
| Step Functions | StartExecution, DescribeExecution |
| Kinesis | PutRecord, PutRecords |
| EventBridge | PutEvents |
| Lambda | InvokeFunction (async) |

### DynamoDB Integration Example

```
┌─────────────────────────────────────────────────────────────────────────┐
│                Direct DynamoDB Integration                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  GET /customers/{id}                                                     │
│        │                                                                 │
│        ▼                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐        │
│  │  Integration Request Template                                │        │
│  │  {                                                           │        │
│  │    "TableName": "Customers",                                 │        │
│  │    "Key": {                                                  │        │
│  │      "customerId": {"S": "$input.params('id')"}             │        │
│  │    }                                                         │        │
│  │  }                                                           │        │
│  └─────────────────────────────────────────────────────────────┘        │
│        │                                                                 │
│        ▼                                                                 │
│  DynamoDB GetItem                                                        │
│        │                                                                 │
│        ▼                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐        │
│  │  Integration Response Template                               │        │
│  │  #set($item = $input.path('$.Item'))                        │        │
│  │  {                                                           │        │
│  │    "id": "$item.customerId.S",                              │        │
│  │    "name": "$item.name.S",                                  │        │
│  │    "email": "$item.email.S"                                 │        │
│  │  }                                                           │        │
│  └─────────────────────────────────────────────────────────────┘        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### AWS Service Integration Configuration

```yaml
# CloudFormation for DynamoDB integration
GetCustomerMethod:
  Type: AWS::ApiGateway::Method
  Properties:
    RestApiId: !Ref MyApi
    ResourceId: !Ref CustomerResource
    HttpMethod: GET
    AuthorizationType: AWS_IAM
    Integration:
      Type: AWS
      IntegrationHttpMethod: POST
      Uri: !Sub arn:aws:apigateway:${AWS::Region}:dynamodb:action/GetItem
      Credentials: !GetAtt ApiGatewayRole.Arn
      RequestTemplates:
        application/json: |
          {
            "TableName": "Customers",
            "Key": {
              "customerId": {"S": "$input.params('id')"}
            }
          }
      IntegrationResponses:
        - StatusCode: 200
          ResponseTemplates:
            application/json: |
              #set($item = $input.path('$.Item'))
              #if($item == "")
                #set($context.responseOverride.status = 404)
                {"error": "Customer not found"}
              #else
                {
                  "id": "$item.customerId.S",
                  "name": "$item.name.S"
                }
              #end
```

### S3 Integration Example

```yaml
# Direct S3 GetObject integration
GetFileMethod:
  Type: AWS::ApiGateway::Method
  Properties:
    HttpMethod: GET
    Integration:
      Type: AWS
      IntegrationHttpMethod: GET
      Uri: !Sub arn:aws:apigateway:${AWS::Region}:s3:path/{bucket}/{key}
      Credentials: !GetAtt ApiGatewayS3Role.Arn
      RequestParameters:
        integration.request.path.bucket: method.request.path.bucket
        integration.request.path.key: method.request.path.key
      IntegrationResponses:
        - StatusCode: 200
          ResponseParameters:
            method.response.header.Content-Type: integration.response.header.Content-Type
```

### Step Functions Integration

```yaml
# Start Step Functions execution
StartWorkflowMethod:
  Type: AWS::ApiGateway::Method
  Properties:
    HttpMethod: POST
    Integration:
      Type: AWS
      IntegrationHttpMethod: POST
      Uri: !Sub arn:aws:apigateway:${AWS::Region}:states:action/StartExecution
      Credentials: !GetAtt ApiGatewayStepFunctionsRole.Arn
      RequestTemplates:
        application/json: |
          {
            "stateMachineArn": "arn:aws:states:region:account:stateMachine:MyWorkflow",
            "input": "$util.escapeJavaScript($input.json('$'))"
          }
```

## 4. VPC Link Integration

Connect API Gateway to private resources in your VPC.

### VPC Link Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      VPC Link Integration                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Internet                                                                │
│     │                                                                    │
│     ▼                                                                    │
│  ┌─────────────────┐                                                    │
│  │  API Gateway    │  (Public endpoint)                                 │
│  │  (Regional)     │                                                    │
│  └────────┬────────┘                                                    │
│           │                                                              │
│           │ VPC Link (PrivateLink)                                      │
│           │                                                              │
│  ┌────────┼─────────────────────────────────────────────────────────┐   │
│  │  VPC   │                                                          │   │
│  │        ▼                                                          │   │
│  │  ┌─────────────────┐                                              │   │
│  │  │  Network Load   │  (REST API VPC Link)                        │   │
│  │  │  Balancer (NLB) │                                              │   │
│  │  └────────┬────────┘                                              │   │
│  │           │                                                       │   │
│  │     ┌─────┴─────┐                                                 │   │
│  │     ▼           ▼                                                 │   │
│  │  ┌──────┐    ┌──────┐                                             │   │
│  │  │ ECS  │    │ EC2  │  (Private subnets)                         │   │
│  │  │ Task │    │      │                                             │   │
│  │  └──────┘    └──────┘                                             │   │
│  │                                                                   │   │
│  └───────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### VPC Link Types

| API Type | VPC Link Target | Use Case |
|----------|-----------------|----------|
| REST API | Network Load Balancer (NLB) | High performance TCP/TLS |
| HTTP API | ALB, NLB, or Cloud Map | More flexible, easier setup |

### Creating VPC Link for REST API

```yaml
# Network Load Balancer
NetworkLoadBalancer:
  Type: AWS::ElasticLoadBalancingV2::LoadBalancer
  Properties:
    Type: network
    Scheme: internal
    Subnets:
      - !Ref PrivateSubnet1
      - !Ref PrivateSubnet2

# VPC Link
VpcLink:
  Type: AWS::ApiGateway::VpcLink
  Properties:
    Name: MyVpcLink
    TargetArns:
      - !Ref NetworkLoadBalancer

# API Method using VPC Link
GetServiceMethod:
  Type: AWS::ApiGateway::Method
  Properties:
    Integration:
      Type: HTTP_PROXY
      IntegrationHttpMethod: GET
      Uri: http://my-internal-service.local:8080/api/resource
      ConnectionType: VPC_LINK
      ConnectionId: !Ref VpcLink
```

### Creating VPC Link for HTTP API

```yaml
# VPC Link for HTTP API (supports ALB)
HttpApiVpcLink:
  Type: AWS::ApiGatewayV2::VpcLink
  Properties:
    Name: MyHttpApiVpcLink
    SubnetIds:
      - !Ref PrivateSubnet1
      - !Ref PrivateSubnet2
    SecurityGroupIds:
      - !Ref VpcLinkSecurityGroup

# HTTP API with VPC Link
HttpApi:
  Type: AWS::ApiGatewayV2::Api
  Properties:
    Name: MyHttpApi
    ProtocolType: HTTP

HttpApiIntegration:
  Type: AWS::ApiGatewayV2::Integration
  Properties:
    ApiId: !Ref HttpApi
    IntegrationType: HTTP_PROXY
    IntegrationMethod: ANY
    IntegrationUri: !Ref ALBListener
    ConnectionType: VPC_LINK
    ConnectionId: !Ref HttpApiVpcLink
```

## 5. Mock Integration

Return predefined responses without a backend.

### Use Cases for Mock Integration

| Use Case | Description |
|----------|-------------|
| API prototyping | Test API design before implementation |
| CORS preflight | Handle OPTIONS requests |
| Health checks | Simple /health endpoint |
| Static responses | Fixed data endpoints |
| Error simulation | Test error handling |

### Mock Integration Example

```yaml
# Health check endpoint
HealthCheckMethod:
  Type: AWS::ApiGateway::Method
  Properties:
    HttpMethod: GET
    AuthorizationType: NONE
    Integration:
      Type: MOCK
      RequestTemplates:
        application/json: '{"statusCode": 200}'
      IntegrationResponses:
        - StatusCode: 200
          ResponseTemplates:
            application/json: |
              {
                "status": "healthy",
                "timestamp": "$context.requestTime",
                "version": "1.0.0"
              }
    MethodResponses:
      - StatusCode: 200
```

### Dynamic Mock Responses

```velocity
## Mock integration with conditional responses
#set($id = $input.params('id'))
#if($id == "1")
{
  "id": "1",
  "name": "Test Customer",
  "email": "test@example.com"
}
#elseif($id == "error")
#set($context.responseOverride.status = 500)
{
  "error": "Simulated server error"
}
#else
#set($context.responseOverride.status = 404)
{
  "error": "Customer not found"
}
#end
```

## 6. Integration Best Practices

### Choosing the Right Integration

```
┌─────────────────────────────────────────────────────────────────────────┐
│                  Integration Selection Guide                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Start                                                                   │
│    │                                                                     │
│    ▼                                                                     │
│  ┌────────────────────────────┐                                         │
│  │ Need compute/business logic?│                                        │
│  └────────────────────────────┘                                         │
│           │                                                              │
│    No     │     Yes                                                     │
│    │      │                                                              │
│    │      └──▶ ┌────────────────────────────┐                           │
│    │           │ Is backend serverless?     │                           │
│    │           └────────────────────────────┘                           │
│    │                │                                                    │
│    │         Yes    │    No                                             │
│    │          │     │                                                    │
│    │          │     └──▶ ┌────────────────┐                             │
│    │          │          │ Backend in VPC? │                             │
│    │          │          └────────────────┘                             │
│    │          │               │                                          │
│    │          │        Yes    │    No                                   │
│    │          │         │     │                                          │
│    │          ▼         ▼     ▼                                          │
│    │    ┌────────┐ ┌────────┐ ┌────────┐                                │
│    │    │ Lambda │ │VPC Link│ │  HTTP  │                                │
│    │    │ Proxy  │ │        │ │ Proxy  │                                │
│    │    └────────┘ └────────┘ └────────┘                                │
│    │                                                                     │
│    └──▶ ┌────────────────────────────┐                                  │
│         │ Direct AWS Service call?    │                                  │
│         └────────────────────────────┘                                  │
│              │                                                           │
│       Yes    │    No                                                    │
│        │     │                                                           │
│        ▼     ▼                                                           │
│   ┌────────┐ ┌────────┐                                                 │
│   │  AWS   │ │  Mock  │                                                 │
│   │Service │ │        │                                                 │
│   └────────┘ └────────┘                                                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Performance Considerations

| Integration Type | Latency | Scalability | Cost |
|-----------------|---------|-------------|------|
| Lambda Proxy | ~100ms cold start | Auto-scaling | Per invocation |
| HTTP Proxy | Network latency | Backend dependent | Per request |
| AWS Service | Low | Service limits | Per request + service |
| VPC Link | Network latency | Backend dependent | Per request + NLB |
| Mock | Lowest | Unlimited | Per request only |

### Error Handling Pattern

```yaml
IntegrationResponses:
  # Success
  - StatusCode: 200
    SelectionPattern: ''
    ResponseTemplates:
      application/json: $input.body

  # Client errors (4xx from backend)
  - StatusCode: 400
    SelectionPattern: '4\d{2}'
    ResponseTemplates:
      application/json: |
        {
          "error": "Bad request",
          "details": $input.path('$.message')
        }

  # Server errors (5xx from backend)
  - StatusCode: 500
    SelectionPattern: '5\d{2}'
    ResponseTemplates:
      application/json: |
        {
          "error": "Internal server error",
          "requestId": "$context.requestId"
        }

  # Timeout
  - StatusCode: 504
    SelectionPattern: 'Task timed out.*'
    ResponseTemplates:
      application/json: |
        {
          "error": "Request timeout",
          "requestId": "$context.requestId"
        }
```

## Key Takeaways

1. **Lambda Proxy is default choice** - Simple, flexible, all logic in code
2. **Use AWS Service integration wisely** - Great for simple CRUD, reduces Lambda costs
3. **VPC Link enables hybrid** - Connect to existing infrastructure securely
4. **HTTP Proxy for microservices** - Easy integration with existing services
5. **Mock for development** - Prototype APIs before implementation
6. **Consider latency and cost** - Each integration type has tradeoffs

## Further Reading

- [Lambda Integration](https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-integrations.html)
- [HTTP Integration](https://docs.aws.amazon.com/apigateway/latest/developerguide/setup-http-integrations.html)
- [AWS Service Integration](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-integration-types.html)
- [VPC Link](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vpc-links.html)
