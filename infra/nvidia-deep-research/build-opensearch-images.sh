#!/bin/bash

#---------------------------------------------------------------
# Build OpenSearch-Enabled RAG Docker Images
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
    echo "Usage: ./build-opensearch-images.sh"
    echo "Builds custom RAG images with OpenSearch support and pushes to ECR."
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
for var in ACCOUNT_ID REGION NGC_API_KEY; do
    if [ -z "${!var}" ]; then
        print_error "Missing $var. Run ./setup-environment.sh"
        exit 1
    fi
done

# Check Docker
if ! docker info &>/dev/null; then
    print_error "Docker not running"
    exit 1
fi

# Clone RAG source
if [ ! -d "rag" ]; then
    print_info "Cloning RAG v2.3.0..."
    git clone -b v2.3.0 https://github.com/NVIDIA-AI-Blueprints/rag.git rag
    print_success "Cloned"
fi

# Download OpenSearch implementation
if [ ! -d "opensearch" ]; then
    print_info "Downloading OpenSearch implementation..."
    COMMIT_HASH="47cd8b345e5049d49d8beb406372de84bd005abe"
    curl -sL "https://github.com/NVIDIA/nim-deploy/archive/${COMMIT_HASH}.tar.gz" | \
        tar xz --strip=5 "nim-deploy-${COMMIT_HASH}/cloud-service-providers/aws/blueprints/deep-research-blueprint-eks/opensearch"
    print_success "Downloaded"
fi

# Integrate OpenSearch
print_info "Integrating OpenSearch into RAG source..."
cp -r opensearch/vdb/opensearch rag/src/nvidia_rag/utils/vdb/
cp opensearch/main.py rag/src/nvidia_rag/ingestor_server/main.py
cp opensearch/vdb/__init__.py rag/src/nvidia_rag/utils/vdb/__init__.py
cp opensearch/pyproject.toml rag/pyproject.toml
print_success "Integrated"

# Login to registries
print_info "Logging into NGC..."
echo "$NGC_API_KEY" | docker login nvcr.io --username '$oauthtoken' --password-stdin > /dev/null
print_success "Logged into NGC"

print_info "Logging into ECR..."
aws ecr get-login-password --region "${REGION}" | \
    docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com" > /dev/null
print_success "Logged into ECR"

# Build and push images
print_info "Building images (this may take 15-30 minutes)..."
bash opensearch/build-opensearch-images.sh
print_success "Images built and pushed to ECR"
