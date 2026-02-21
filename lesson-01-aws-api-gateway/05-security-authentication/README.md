# 05. Security and Authentication

## Overview

Security is critical for any API. AWS API Gateway provides multiple layers of security including authentication, authorization, encryption, and protection against common web exploits. This lesson covers all security features available in API Gateway.

## Learning Objectives

- Understand all authentication options in API Gateway
- Implement IAM, Cognito, and Lambda authorizers
- Configure API keys and usage plans
- Set up mTLS for certificate-based authentication
- Integrate AWS WAF for threat protection
- Apply resource policies for access control

## Security Layers Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                   API Gateway Security Layers                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Layer 1: Edge Protection                                                │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  AWS WAF │ DDoS Protection (Shield) │ CloudFront (Edge)        │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Layer 2: Network Security                                               │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  TLS 1.2+ │ mTLS │ Private APIs │ VPC Endpoints                 │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Layer 3: Authentication                                                 │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  IAM │ Cognito User Pools │ Lambda Authorizer │ JWT (HTTP API) │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Layer 4: Authorization                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  IAM Policies │ Resource Policies │ Scope-based (OAuth)         │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Layer 5: Rate Limiting                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  API Keys │ Usage Plans │ Throttling │ Quotas                   │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 1. Authentication Options Comparison

| Feature | IAM Auth | Cognito | Lambda Authorizer | JWT (HTTP API) | API Keys |
|---------|----------|---------|-------------------|----------------|----------|
| **Use Case** | AWS services, internal | Mobile/Web users | Custom auth logic | OAuth/OIDC providers | Rate limiting |
| **Token Type** | SigV4 signature | JWT (Cognito) | Custom | JWT | API Key string |
| **Caching** | N/A | Built-in | Configurable | Built-in | N/A |
| **REST API** | Yes | Yes | Yes | No (use Lambda) | Yes |
| **HTTP API** | Yes | Via JWT | Yes | Yes | No |
| **Cost** | Free | Free | Lambda cost | Free | Free |

## 2. IAM Authentication

Best for AWS service-to-service communication and internal tools.

### How IAM Auth Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    IAM Authentication Flow                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Client (with IAM credentials)                                           │
│     │                                                                    │
│     │  1. Create canonical request                                      │
│     │  2. Sign with AWS Signature V4                                    │
│     │                                                                    │
│     ▼                                                                    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Request Headers:                                                │    │
│  │  Authorization: AWS4-HMAC-SHA256 Credential=AKIA.../20240115/   │    │
│  │                 region/execute-api/aws4_request,                 │    │
│  │                 SignedHeaders=host;x-amz-date,                   │    │
│  │                 Signature=abc123...                              │    │
│  │  X-Amz-Date: 20240115T120000Z                                   │    │
│  │  X-Amz-Security-Token: ... (for temporary credentials)          │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│     │                                                                    │
│     ▼                                                                    │
│  API Gateway                                                             │
│     │                                                                    │
│     │  3. Verify signature                                              │
│     │  4. Check IAM policy permissions                                  │
│     │                                                                    │
│     ▼                                                                    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  IAM Policy Check:                                               │    │
│  │  Action: execute-api:Invoke                                      │    │
│  │  Resource: arn:aws:execute-api:region:account:api-id/stage/METHOD/path │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### IAM Policy Example

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "execute-api:Invoke",
      "Resource": [
        "arn:aws:execute-api:us-east-1:123456789:abc123/prod/GET/customers",
        "arn:aws:execute-api:us-east-1:123456789:abc123/prod/GET/customers/*"
      ]
    },
    {
      "Effect": "Deny",
      "Action": "execute-api:Invoke",
      "Resource": "arn:aws:execute-api:us-east-1:123456789:abc123/prod/DELETE/*"
    }
  ]
}
```

### Calling API with IAM Auth (Python)

```python
import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import requests

def call_api_with_iam():
    session = boto3.Session()
    credentials = session.get_credentials()
    region = 'us-east-1'

    url = 'https://abc123.execute-api.us-east-1.amazonaws.com/prod/customers'

    request = AWSRequest(method='GET', url=url)
    SigV4Auth(credentials, 'execute-api', region).add_auth(request)

    response = requests.get(url, headers=dict(request.headers))
    return response.json()
```

## 3. Amazon Cognito Integration

Best for web and mobile applications with user authentication.

### Cognito User Pools Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Cognito User Pool Authentication                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Mobile/Web App                                                          │
│     │                                                                    │
│     │  1. User signs in (username/password, social, SAML)              │
│     ▼                                                                    │
│  ┌─────────────────┐                                                    │
│  │  Cognito User   │                                                    │
│  │  Pool           │                                                    │
│  └────────┬────────┘                                                    │
│           │                                                              │
│           │  2. Return tokens (ID, Access, Refresh)                     │
│           ▼                                                              │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Tokens:                                                         │    │
│  │  • ID Token: User identity (name, email, custom attributes)     │    │
│  │  • Access Token: API authorization (scopes, groups)             │    │
│  │  • Refresh Token: Obtain new tokens                              │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│           │                                                              │
│           │  3. Call API with ID/Access token                           │
│           ▼                                                              │
│  ┌─────────────────┐     4. Validate token     ┌─────────────────┐     │
│  │  API Gateway    │◀─────────────────────────▶│  Cognito        │     │
│  │  (Authorizer)   │                           │  (JWKS endpoint)│     │
│  └────────┬────────┘                           └─────────────────┘     │
│           │                                                              │
│           │  5. Forward to backend with claims                          │
│           ▼                                                              │
│  ┌─────────────────┐                                                    │
│  │  Lambda/Backend │  $context.authorizer.claims.email                 │
│  └─────────────────┘                                                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Cognito Authorizer Configuration (REST API)

```yaml
CognitoAuthorizer:
  Type: AWS::ApiGateway::Authorizer
  Properties:
    Name: CognitoAuthorizer
    Type: COGNITO_USER_POOLS
    RestApiId: !Ref MyApi
    IdentitySource: method.request.header.Authorization
    ProviderARNs:
      - !GetAtt UserPool.Arn

# Method using Cognito authorizer
GetCustomersMethod:
  Type: AWS::ApiGateway::Method
  Properties:
    AuthorizationType: COGNITO_USER_POOLS
    AuthorizerId: !Ref CognitoAuthorizer
    AuthorizationScopes:
      - customers/read  # OAuth scopes (optional)
```

### Accessing User Claims in Lambda

```python
def handler(event, context):
    # Access Cognito claims from authorizer
    claims = event['requestContext']['authorizer']['claims']

    user_id = claims['sub']  # Cognito user ID
    email = claims['email']
    groups = claims.get('cognito:groups', '').split(',')
    custom_attr = claims.get('custom:tenant_id')

    # Use claims for authorization
    if 'admin' not in groups:
        return {
            'statusCode': 403,
            'body': json.dumps({'error': 'Admin access required'})
        }

    return {
        'statusCode': 200,
        'body': json.dumps({'user': email, 'groups': groups})
    }
```

## 4. Lambda Authorizers

Best for custom authentication logic (API tokens, third-party auth).

### Lambda Authorizer Types

| Type | Input | Output | Caching | Use Case |
|------|-------|--------|---------|----------|
| Token | Authorization header | IAM Policy | By token | Bearer tokens, API keys |
| Request | Headers, query, path | IAM Policy | By context | Multiple parameters, IP-based |

### Token-Based Lambda Authorizer

```
┌─────────────────────────────────────────────────────────────────────────┐
│                   Token Lambda Authorizer Flow                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Client                                                                  │
│     │                                                                    │
│     │  Authorization: Bearer eyJhbGciOiJIUzI1...                        │
│     ▼                                                                    │
│  API Gateway                                                             │
│     │                                                                    │
│     │  1. Extract token from header                                     │
│     │  2. Check cache (if enabled)                                      │
│     │  3. If not cached, invoke Lambda                                  │
│     ▼                                                                    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Lambda Authorizer                                               │    │
│  │  Input: { "authorizationToken": "Bearer eyJ...", "methodArn": ...}│   │
│  │                                                                   │    │
│  │  Processing:                                                      │    │
│  │  • Validate token signature                                       │    │
│  │  • Check expiration                                               │    │
│  │  • Verify claims/permissions                                      │    │
│  │  • Generate IAM policy                                            │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│     │                                                                    │
│     │  4. Return policy                                                 │
│     │  5. Cache policy (if configured)                                  │
│     │  6. Evaluate policy against request                               │
│     ▼                                                                    │
│  Backend                                                                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Lambda Authorizer Implementation

```python
import jwt
import json
from datetime import datetime

SECRET_KEY = "your-secret-key"  # In production, use Secrets Manager

def handler(event, context):
    token = event['authorizationToken'].replace('Bearer ', '')
    method_arn = event['methodArn']

    try:
        # Validate JWT
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])

        # Check expiration
        if datetime.utcnow().timestamp() > payload['exp']:
            raise Exception('Token expired')

        # Generate policy
        principal_id = payload['sub']
        permissions = payload.get('permissions', [])

        return generate_policy(
            principal_id=principal_id,
            effect='Allow',
            resource=method_arn,
            context={
                'userId': principal_id,
                'email': payload.get('email', ''),
                'permissions': ','.join(permissions)
            }
        )

    except jwt.InvalidTokenError as e:
        print(f"Token validation failed: {e}")
        raise Exception('Unauthorized')  # Return 401
    except Exception as e:
        print(f"Authorization failed: {e}")
        raise Exception('Unauthorized')

def generate_policy(principal_id, effect, resource, context=None):
    policy = {
        'principalId': principal_id,
        'policyDocument': {
            'Version': '2012-10-17',
            'Statement': [{
                'Action': 'execute-api:Invoke',
                'Effect': effect,
                'Resource': resource
            }]
        }
    }

    if context:
        policy['context'] = context

    return policy
```

### Request-Based Lambda Authorizer

```python
def handler(event, context):
    """
    Request-based authorizer with access to:
    - Headers
    - Query string parameters
    - Path parameters
    - Stage variables
    - Request context
    """
    headers = event.get('headers', {})
    query_params = event.get('queryStringParameters', {})
    path_params = event.get('pathParameters', {})
    stage_vars = event.get('stageVariables', {})
    request_context = event.get('requestContext', {})

    # Custom authorization logic
    api_key = headers.get('x-api-key')
    client_ip = request_context.get('identity', {}).get('sourceIp')

    # Example: Check API key and IP whitelist
    if not validate_api_key(api_key):
        raise Exception('Unauthorized')

    if not is_ip_allowed(client_ip):
        raise Exception('Unauthorized')

    # Generate policy allowing access
    return {
        'principalId': api_key,
        'policyDocument': {
            'Version': '2012-10-17',
            'Statement': [{
                'Action': 'execute-api:Invoke',
                'Effect': 'Allow',
                'Resource': event['methodArn']
            }]
        },
        'context': {
            'clientIp': client_ip,
            'apiKeyId': api_key
        }
    }
```

### Lambda Authorizer Caching

```yaml
LambdaAuthorizer:
  Type: AWS::ApiGateway::Authorizer
  Properties:
    Name: CustomAuthorizer
    Type: TOKEN
    RestApiId: !Ref MyApi
    IdentitySource: method.request.header.Authorization
    AuthorizerUri: !Sub arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${AuthorizerFunction.Arn}/invocations
    AuthorizerResultTtlInSeconds: 300  # Cache for 5 minutes
```

## 5. JWT Authorizers (HTTP API)

Native JWT validation for HTTP APIs without Lambda.

### JWT Authorizer Configuration

```yaml
HttpApi:
  Type: AWS::Serverless::HttpApi
  Properties:
    Auth:
      DefaultAuthorizer: JwtAuthorizer
      Authorizers:
        JwtAuthorizer:
          AuthorizationScopes:
            - read:customers
            - write:customers
          IdentitySource: $request.header.Authorization
          JwtConfiguration:
            issuer: https://your-domain.auth0.com/
            audience:
              - https://api.yourdomain.com
              - your-client-id
```

### Supported JWT Providers

| Provider | Issuer Format | Notes |
|----------|---------------|-------|
| Cognito | https://cognito-idp.{region}.amazonaws.com/{poolId} | Built-in integration |
| Auth0 | https://{tenant}.auth0.com/ | Standard OIDC |
| Okta | https://{domain}.okta.com/oauth2/default | Standard OIDC |
| Azure AD | https://login.microsoftonline.com/{tenantId}/v2.0 | Standard OIDC |
| Google | https://accounts.google.com | OAuth 2.0 |

### JWT Validation Process

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    JWT Validation (HTTP API)                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. Extract JWT from Authorization header                               │
│     Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...      │
│                                                                          │
│  2. Fetch JWKS from issuer (cached)                                     │
│     GET {issuer}/.well-known/jwks.json                                  │
│                                                                          │
│  3. Validate JWT signature                                              │
│     • Verify using public key from JWKS                                 │
│     • Check algorithm matches (RS256)                                   │
│                                                                          │
│  4. Validate claims                                                     │
│     • iss (issuer) matches configuration                                │
│     • aud (audience) matches configuration                              │
│     • exp (expiration) > current time                                   │
│     • nbf (not before) < current time (if present)                      │
│                                                                          │
│  5. Validate scopes (if configured)                                     │
│     • Check scope claim contains required scopes                        │
│     • Scopes can be space-delimited or array                           │
│                                                                          │
│  6. Pass claims to backend                                              │
│     $context.authorizer.jwt.claims.{claimName}                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 6. API Keys and Usage Plans

For tracking and limiting API usage by clients.

### API Keys Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    API Keys and Usage Plans                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐     │
│  │  Partner A      │    │  Partner B      │    │  Partner C      │     │
│  │  API Key: abc...│    │  API Key: def...│    │  API Key: ghi...│     │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘     │
│           │                      │                      │               │
│           └──────────────────────┼──────────────────────┘               │
│                                  │                                       │
│                                  ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                        Usage Plans                               │    │
│  ├─────────────────────────────────────────────────────────────────┤    │
│  │  Gold Plan (Partner A)         │  Silver Plan (B, C)            │    │
│  │  • Rate: 1000 req/sec          │  • Rate: 100 req/sec           │    │
│  │  • Burst: 2000                 │  • Burst: 200                  │    │
│  │  • Quota: 10M/month            │  • Quota: 100K/month           │    │
│  │  • Methods: ALL                │  • Methods: GET only           │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                  │                                       │
│                                  ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Request with x-api-key header                                   │    │
│  │  1. Validate API key exists                                      │    │
│  │  2. Check usage plan limits                                      │    │
│  │  3. Update usage counter                                         │    │
│  │  4. Return 429 if exceeded                                       │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Usage Plan Configuration

```yaml
# API Key
PartnerAApiKey:
  Type: AWS::ApiGateway::ApiKey
  Properties:
    Name: partner-a-production
    Enabled: true

# Usage Plan
GoldUsagePlan:
  Type: AWS::ApiGateway::UsagePlan
  Properties:
    UsagePlanName: gold-plan
    Throttle:
      RateLimit: 1000
      BurstLimit: 2000
    Quota:
      Limit: 10000000
      Period: MONTH
    ApiStages:
      - ApiId: !Ref MyApi
        Stage: prod
        Throttle:
          /payments/POST:
            RateLimit: 100
            BurstLimit: 200

# Link API Key to Usage Plan
GoldUsagePlanKey:
  Type: AWS::ApiGateway::UsagePlanKey
  Properties:
    KeyId: !Ref PartnerAApiKey
    KeyType: API_KEY
    UsagePlanId: !Ref GoldUsagePlan
```

## 7. Mutual TLS (mTLS)

Certificate-based authentication for high-security scenarios.

### mTLS Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Mutual TLS Authentication                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Client                               API Gateway                        │
│     │                                      │                             │
│     │  1. TLS Handshake (ClientHello)     │                             │
│     │─────────────────────────────────────▶│                             │
│     │                                      │                             │
│     │  2. Server Certificate              │                             │
│     │◀─────────────────────────────────────│                             │
│     │                                      │                             │
│     │  3. Client Certificate Request       │                             │
│     │◀─────────────────────────────────────│                             │
│     │                                      │                             │
│     │  4. Client Certificate + Signature  │                             │
│     │─────────────────────────────────────▶│                             │
│     │                                      │                             │
│     │                              5. Verify client cert                 │
│     │                              • Check against truststore           │
│     │                              • Validate certificate chain         │
│     │                              • Check revocation (optional)        │
│     │                                      │                             │
│     │  6. TLS Established                 │                             │
│     │◀────────────────────────────────────▶│                             │
│     │                                      │                             │
│     │  7. API Request                      │                             │
│     │─────────────────────────────────────▶│                             │
│                                                                          │
│  Certificate info available:                                             │
│  • $context.identity.clientCert.subjectDN                               │
│  • $context.identity.clientCert.issuerDN                                │
│  • $context.identity.clientCert.serialNumber                            │
│  • $context.identity.clientCert.validity.notBefore                      │
│  • $context.identity.clientCert.validity.notAfter                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### mTLS Configuration

```yaml
# Custom domain with mTLS
CustomDomain:
  Type: AWS::ApiGateway::DomainName
  Properties:
    DomainName: api.secure.example.com
    RegionalCertificateArn: !Ref ServerCertificate
    SecurityPolicy: TLS_1_2
    MutualTlsAuthentication:
      TruststoreUri: s3://my-bucket/truststore.pem
      TruststoreVersion: abc123  # Optional, for updates
    EndpointConfiguration:
      Types:
        - REGIONAL
```

### Truststore Format

```pem
-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAJC1HiIAZAiUMA0Gcz...
(Root CA Certificate)
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAJC1HiIAZAiUMA0Gcz...
(Intermediate CA Certificate - optional)
-----END CERTIFICATE-----
```

## 8. AWS WAF Integration

Protect APIs from common web exploits.

### WAF Rule Categories

| Category | Protection Against |
|----------|-------------------|
| SQL Injection | SQLi attacks in request body, query strings |
| XSS | Cross-site scripting attacks |
| Size Constraints | Large request bodies |
| IP Reputation | Known malicious IPs |
| Rate-based | DDoS, brute force attacks |
| Geo-blocking | Requests from specific countries |
| Bot Control | Automated bot traffic |

### WAF Configuration Example

```yaml
WebACL:
  Type: AWS::WAFv2::WebACL
  Properties:
    Name: api-gateway-waf
    Scope: REGIONAL
    DefaultAction:
      Allow: {}
    Rules:
      # AWS Managed Rules - Common threats
      - Name: AWSManagedRulesCommonRuleSet
        Priority: 1
        Statement:
          ManagedRuleGroupStatement:
            VendorName: AWS
            Name: AWSManagedRulesCommonRuleSet
        OverrideAction:
          None: {}
        VisibilityConfig:
          SampledRequestsEnabled: true
          CloudWatchMetricsEnabled: true
          MetricName: CommonRuleSetMetric

      # AWS Managed Rules - SQL injection
      - Name: AWSManagedRulesSQLiRuleSet
        Priority: 2
        Statement:
          ManagedRuleGroupStatement:
            VendorName: AWS
            Name: AWSManagedRulesSQLiRuleSet
        OverrideAction:
          None: {}
        VisibilityConfig:
          SampledRequestsEnabled: true
          CloudWatchMetricsEnabled: true
          MetricName: SQLiRuleSetMetric

      # Rate limiting
      - Name: RateLimitRule
        Priority: 3
        Statement:
          RateBasedStatement:
            Limit: 2000  # Per 5 minutes
            AggregateKeyType: IP
        Action:
          Block: {}
        VisibilityConfig:
          SampledRequestsEnabled: true
          CloudWatchMetricsEnabled: true
          MetricName: RateLimitMetric

      # Geo-blocking
      - Name: GeoBlockRule
        Priority: 4
        Statement:
          GeoMatchStatement:
            CountryCodes:
              - RU
              - CN
              - KP
        Action:
          Block: {}
        VisibilityConfig:
          SampledRequestsEnabled: true
          CloudWatchMetricsEnabled: true
          MetricName: GeoBlockMetric

# Associate WAF with API Gateway
WebACLAssociation:
  Type: AWS::WAFv2::WebACLAssociation
  Properties:
    ResourceArn: !Sub arn:aws:apigateway:${AWS::Region}::/restapis/${MyApi}/stages/prod
    WebACLArn: !GetAtt WebACL.Arn
```

## 9. Resource Policies

Control access at the API level.

### Resource Policy Use Cases

| Use Case | Policy Configuration |
|----------|---------------------|
| Cross-account access | Allow specific AWS accounts |
| VPC-only access | Restrict to VPC endpoints |
| IP whitelist | Allow specific IP ranges |
| Condition-based | Time-based, request attributes |

### Resource Policy Examples

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "execute-api:Invoke",
      "Resource": "arn:aws:execute-api:region:account:api-id/*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": [
            "192.0.2.0/24",
            "203.0.113.0/24"
          ]
        }
      }
    },
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "execute-api:Invoke",
      "Resource": "arn:aws:execute-api:region:account:api-id/*/DELETE/*",
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalAccount": "123456789012"
        }
      }
    }
  ]
}
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
          "aws:sourceVpce": "vpce-0a1b2c3d4e5f67890"
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

## Security Best Practices Summary

| Category | Recommendation |
|----------|---------------|
| Authentication | Use Cognito for user auth, IAM for services |
| Authorization | Implement fine-grained permissions |
| Encryption | Enable TLS 1.2+, consider mTLS for B2B |
| Rate Limiting | Always configure throttling |
| WAF | Enable for public APIs |
| Logging | Enable access logging, mask sensitive data |
| API Keys | Use for tracking, not primary auth |
| Resource Policies | Use for network-level restrictions |

## Key Takeaways

1. **Layer your security** - Combine authentication, authorization, and WAF
2. **Choose the right auth method** - IAM for services, Cognito for users
3. **Lambda authorizers are powerful** - Use for custom auth logic
4. **HTTP API JWT is simpler** - Native support without Lambda
5. **API keys are not security** - Use for tracking and rate limiting only
6. **Enable WAF for public APIs** - Protect against common attacks

## Further Reading

- [API Gateway Authentication](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-control-access-to-api.html)
- [Lambda Authorizers](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-authorizer.html)
- [mTLS](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-mutual-tls.html)
- [WAF Integration](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-control-access-aws-waf.html)
