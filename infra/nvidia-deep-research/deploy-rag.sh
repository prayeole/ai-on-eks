#!/bin/bash

#---------------------------------------------------------------
# Deploy NVIDIA Enterprise RAG Blueprint
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
    echo "Usage: ./deploy-rag.sh"
    echo "Deploys Enterprise RAG Blueprint with OpenSearch integration."
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
for var in ACCOUNT_ID REGION NGC_API_KEY OPENSEARCH_ENDPOINT OPENSEARCH_SERVICE_ACCOUNT; do
    if [ -z "${!var}" ]; then
        print_error "Missing $var. Run ./setup-environment.sh"
        exit 1
    fi
done

# Deploy RAG with Helm
print_info "Deploying RAG Blueprint..."
helm upgrade --install rag -n "$OPENSEARCH_NAMESPACE" \
  https://helm.ngc.nvidia.com/nvidia/blueprint/charts/nvidia-blueprint-rag-v2.3.0.tgz \
  --username '$oauthtoken' \
  --password "${NGC_API_KEY}" \
  --create-namespace \
  --set imagePullSecret.password="$NGC_API_KEY" \
  --set ngcApiSecret.password="$NGC_API_KEY" \
  --set serviceAccount.create=false \
  --set serviceAccount.name="$OPENSEARCH_SERVICE_ACCOUNT" \
  --set image.repository="${ECR_REGISTRY}/nvidia-rag-server" \
  --set image.tag="${IMAGE_TAG}" \
  --set ingestor-server.image.repository="${ECR_REGISTRY}/nvidia-rag-ingestor" \
  --set ingestor-server.image.tag="${IMAGE_TAG}" \
  --set envVars.APP_VECTORSTORE_URL="${OPENSEARCH_ENDPOINT}" \
  --set envVars.APP_VECTORSTORE_AWS_REGION="${REGION}" \
  --set ingestor-server.envVars.APP_VECTORSTORE_URL="${OPENSEARCH_ENDPOINT}" \
  --set ingestor-server.envVars.APP_VECTORSTORE_AWS_REGION="${REGION}" \
  -f helm/rag-values-os.yaml

print_success "Deployment initiated"

# Patch ingestor-server
print_info "Patching ingestor-server service account..."
kubectl patch deployment ingestor-server -n "$OPENSEARCH_NAMESPACE" \
  -p "{\"spec\":{\"template\":{\"spec\":{\"serviceAccountName\":\"$OPENSEARCH_SERVICE_ACCOUNT\"}}}}"
print_success "Patched"

# Wait for pods
print_info "Waiting for RAG pods to be ready (may take 15-25 minutes for model downloads)..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/instance=rag \
    -n "$OPENSEARCH_NAMESPACE" \
    --timeout=1800s

print_success "RAG deployed successfully"
