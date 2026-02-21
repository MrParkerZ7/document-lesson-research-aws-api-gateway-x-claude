.PHONY: help build test local-up local-down docker-build docker-push infra-init infra-plan infra-apply deploy destroy

# Default environment
ENV ?= dev
AWS_REGION ?= ap-southeast-1
PROJECT_NAME ?= multi-hop-demo

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ==================== Application Commands ====================

build: ## Build all applications
	cd applications && ./gradlew build

test: ## Run all tests
	cd applications && ./gradlew test

clean: ## Clean build artifacts
	cd applications && ./gradlew clean

# ==================== Local Development ====================

local-up: ## Start local development environment
	docker-compose -f docker/docker-compose.yml up -d

local-down: ## Stop local development environment
	docker-compose -f docker/docker-compose.yml down

local-logs: ## View local environment logs
	docker-compose -f docker/docker-compose.yml logs -f

# ==================== Docker Commands ====================

docker-build: ## Build Docker images
	cd applications && \
	docker build -t $(PROJECT_NAME)/account-service:latest -f account-service/Dockerfile . && \
	docker build -t $(PROJECT_NAME)/transfer-service:latest -f transfer-service/Dockerfile .

docker-push: ## Push images to ECR
	@echo "Logging into ECR..."
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $$(terraform -chdir=infrastructure output -raw ecr_registry_url)
	@echo "Tagging and pushing images..."
	docker tag $(PROJECT_NAME)/account-service:latest $$(terraform -chdir=infrastructure output -raw account_service_ecr_url):latest
	docker tag $(PROJECT_NAME)/transfer-service:latest $$(terraform -chdir=infrastructure output -raw transfer_service_ecr_url):latest
	docker push $$(terraform -chdir=infrastructure output -raw account_service_ecr_url):latest
	docker push $$(terraform -chdir=infrastructure output -raw transfer_service_ecr_url):latest

# ==================== Infrastructure Commands ====================

infra-init: ## Initialize Terraform
	cd infrastructure && terraform init -backend-config=environments/$(ENV)/backend.hcl

infra-plan: ## Plan infrastructure changes
	cd infrastructure && terraform plan -var-file=environments/$(ENV)/terraform.tfvars -out=tfplan

infra-apply: ## Apply infrastructure changes
	cd infrastructure && terraform apply tfplan

infra-destroy: ## Destroy infrastructure (use with caution!)
	cd infrastructure && terraform destroy -var-file=environments/$(ENV)/terraform.tfvars

infra-output: ## Show Terraform outputs
	cd infrastructure && terraform output

# ==================== Deployment Commands ====================

deploy: docker-build docker-push ## Build, push, and deploy
	@echo "Updating ECS services..."
	aws ecs update-service --cluster $(PROJECT_NAME)-$(ENV) --service account-service --force-new-deployment --region $(AWS_REGION)
	aws ecs update-service --cluster $(PROJECT_NAME)-$(ENV) --service transfer-service --force-new-deployment --region $(AWS_REGION)

# ==================== Full Lifecycle ====================

setup: infra-init infra-plan infra-apply deploy ## Full setup: infrastructure + deployment

destroy: ## Destroy everything (use with extreme caution!)
	@echo "WARNING: This will destroy all resources!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	$(MAKE) infra-destroy
