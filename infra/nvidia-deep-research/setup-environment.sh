#!/bin/bash

#---------------------------------------------------------------
# Setup Environment for NVIDIA Enterprise RAG & AI-Q Deployment
#---------------------------------------------------------------

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Usage: ./setup-environment.sh"
    echo "Configures kubectl, sets environment variables, and verifies cluster readiness."
    exit 0
fi

# Get cluster details from Terraform outputs
print_info "Retrieving cluster details from Terraform..."
if [ ! -d "terraform/_LOCAL" ]; then
    print_error "Terraform directory not found. Please run ./install.sh first to deploy infrastructure."
    exit 1
fi

cd terraform/_LOCAL

# Get kubectl configuration command from Terraform
KUBECTL_CMD=$(terraform output -raw configure_kubectl 2>/dev/null)
OPENSEARCH_ENDPOINT=$(terraform output -raw opensearch_collection_endpoint 2>/dev/null)

cd - > /dev/null

if [ -z "$KUBECTL_CMD" ]; then
    print_error "Failed to retrieve cluster details from Terraform. Ensure infrastructure is deployed successfully."
    exit 1
fi

# Extract region and cluster name from kubectl command for .env file
REGION=$(echo "$KUBECTL_CMD" | sed -n 's/.*--region \([^ ]*\).*/\1/p')
CLUSTER_NAME=$(echo "$KUBECTL_CMD" | sed -n 's/.*--name \([^ ]*\).*/\1/p')

# Configure kubectl using Terraform's command
print_info "Configuring kubectl..."
eval "$KUBECTL_CMD"

if kubectl get nodes &>/dev/null; then
    print_success "Connected to cluster"
else
    print_error "Failed to connect to cluster"
    exit 1
fi

# Set environment variables
print_info "Getting AWS Account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

OPENSEARCH_SERVICE_ACCOUNT="opensearch-access-sa"
OPENSEARCH_NAMESPACE="rag"
COLLECTION_NAME="osv-vector-dev"

if [ -z "$OPENSEARCH_ENDPOINT" ]; then
    print_error "Failed to retrieve OpenSearch endpoint from Terraform. Ensure infrastructure is deployed."
    exit 1
fi
print_success "OpenSearch endpoint retrieved"

# Collect API Keys
if [ -z "$NGC_API_KEY" ]; then
    read -sp "Enter NGC API Key: " NGC_API_KEY
    echo ""
fi

if [ -z "$NGC_API_KEY" ]; then
    print_error "NGC API Key is required. Get your key from: https://org.ngc.nvidia.com/setup/personal-keys"
    exit 1
fi

read -p "Deploy AI-Q? (y/n) [n]: " DEPLOY_AIRA
DEPLOY_AIRA=${DEPLOY_AIRA:-n}

if [[ "$DEPLOY_AIRA" =~ ^[Yy] ]]; then
    if [ -z "$TAVILY_API_KEY" ]; then
        echo ""
        print_info "Tavily API Key (optional): Enables web search in AI-Q. Leave blank to use RAG-only mode."
        read -sp "Enter Tavily API Key (or press Enter to skip): " TAVILY_API_KEY
        echo ""
    fi

    if [ -z "$TAVILY_API_KEY" ]; then
        print_info "AI-Q will deploy without web search capabilities (RAG-only mode)"
    fi
fi

# Verify cluster
print_info "Verifying cluster..."
if ! kubectl get pods -n karpenter | grep -q "Running"; then
    print_error "Karpenter not running"
    exit 1
fi
print_success "Karpenter running"

# Patch Karpenter NodePool
if kubectl get nodepool g5-gpu-karpenter &>/dev/null; then
    print_info "Patching g5-gpu-karpenter memory limit to 2000Gi..."
    kubectl patch nodepool g5-gpu-karpenter --type='json' \
        -p='[{"op": "replace", "path": "/spec/limits/memory", "value": "2000Gi"}]'
    print_success "NodePool patched"
fi

# Save configuration
cat > .env << EOF
export CLUSTER_NAME="$CLUSTER_NAME"
export REGION="$REGION"
export ACCOUNT_ID="$ACCOUNT_ID"
export OPENSEARCH_SERVICE_ACCOUNT="$OPENSEARCH_SERVICE_ACCOUNT"
export OPENSEARCH_NAMESPACE="$OPENSEARCH_NAMESPACE"
export COLLECTION_NAME="$COLLECTION_NAME"
export OPENSEARCH_ENDPOINT="$OPENSEARCH_ENDPOINT"
export ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
export IMAGE_TAG="2.3.0-opensearch"
export NGC_API_KEY="$NGC_API_KEY"
EOF

if [ -n "$TAVILY_API_KEY" ]; then
    echo "export TAVILY_API_KEY=\"$TAVILY_API_KEY\"" >> .env
fi

print_success "Configuration saved to .env"
