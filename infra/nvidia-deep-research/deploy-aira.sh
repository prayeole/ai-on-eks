#!/bin/bash

#---------------------------------------------------------------
# Deploy NVIDIA AI-Q Research Assistant
#---------------------------------------------------------------

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Usage: ./deploy-aira.sh"
    echo "Deploys AI-Q Research Assistant with web search capabilities."
    exit 0
fi

# Load environment
if [ -f .env ]; then
    source .env
else
    print_error ".env not found. Run ./setup-environment.sh first"
    exit 1
fi

# Verify required variables
for var in NGC_API_KEY TAVILY_API_KEY; do
    if [ -z "${!var}" ]; then
        print_error "Missing $var"
        exit 1
    fi
done

# Check if RAG is deployed
if ! kubectl get namespace rag &>/dev/null; then
    print_error "RAG not deployed. Run ./deploy-rag.sh first"
    exit 1
fi

# Deploy AIRA
print_info "Deploying AI-Q..."
helm upgrade --install aira \
  https://helm.ngc.nvidia.com/nvidia/blueprint/charts/aiq-aira-v1.2.0.tgz \
  --username='$oauthtoken' \
  --password="${NGC_API_KEY}" \
  -n nv-aira \
  --create-namespace \
  -f helm/aira-values.eks.yaml \
  --set imagePullSecret.password="$NGC_API_KEY" \
  --set ngcApiSecret.password="$NGC_API_KEY" \
  --set tavilyApiSecret.password="$TAVILY_API_KEY"

print_success "Deployment initiated"

# Wait for pods
print_info "Waiting for AI-Q pods to be ready (may take 25-30 minutes for 70B model download)..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/instance=aira \
    -n nv-aira \
    --timeout=2400s

print_success "AI-Q deployed successfully"
