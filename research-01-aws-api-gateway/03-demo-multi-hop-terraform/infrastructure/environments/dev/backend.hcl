# S3 Backend Configuration for Dev Environment
# Update these values with your actual S3 bucket and DynamoDB table

bucket         = "your-terraform-state-bucket"
key            = "multi-hop-demo/dev/terraform.tfstate"
region         = "ap-southeast-1"
encrypt        = true
dynamodb_table = "terraform-state-lock"
