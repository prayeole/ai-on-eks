#!/bin/bash

#---------------------------------------------------------------
# Data Ingestion from S3 to RAG
#---------------------------------------------------------------

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Usage: ./data_ingestion.sh"
    echo "Downloads files from S3 and ingests into RAG vector database."
    echo ""
    echo "Supported file types: PDF, DOCX, TXT, images"
    exit 0
fi

# Prompt for S3 configuration if not set
if [ -z "$S3_BUCKET_NAME" ]; then
    read -p "S3 bucket name: " S3_BUCKET_NAME
fi

if [ -z "$S3_PREFIX" ]; then
    read -p "S3 prefix (optional, press enter to skip): " S3_PREFIX
fi

# Set defaults
INGESTOR_URL="${INGESTOR_URL:-localhost:8082}"
RAG_COLLECTION_NAME="${RAG_COLLECTION_NAME:-multimodal_data}"
LOCAL_DATA_DIR="${LOCAL_DATA_DIR:-/tmp/s3_ingestion}"
UPLOAD_BATCH_SIZE="${UPLOAD_BATCH_SIZE:-100}"

# Parse ingestor URL
INGESTOR_HOST="${INGESTOR_URL%%:*}"
INGESTOR_PORT="${INGESTOR_URL##*:}"

print_info "Downloading from s3://$S3_BUCKET_NAME/$S3_PREFIX"

# Download from S3
mkdir -p "$LOCAL_DATA_DIR"
aws s3 sync "s3://$S3_BUCKET_NAME/$S3_PREFIX" "$LOCAL_DATA_DIR" \
  --exclude "*" --include "*.pdf" --include "*.docx" --include "*.txt"

# Download batch ingestion script from NVIDIA RAG repository
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMP_DIR="/tmp/rag_ingestion_$$"
mkdir -p "$TEMP_DIR"

print_info "Downloading batch ingestion script from NVIDIA RAG repository..."
RAG_VERSION="v2.3.0"
RAG_BASE_URL="https://raw.githubusercontent.com/NVIDIA-AI-Blueprints/rag/${RAG_VERSION}"

# Download batch_ingestion.py and requirements.txt
curl -sL "${RAG_BASE_URL}/scripts/batch_ingestion.py" -o "$TEMP_DIR/batch_ingestion.py"
curl -sL "${RAG_BASE_URL}/scripts/requirements.txt" -o "$TEMP_DIR/requirements.txt"

if [ ! -f "$TEMP_DIR/batch_ingestion.py" ]; then
    print_error "Failed to download batch_ingestion.py"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Install dependencies
print_info "Installing dependencies..."
python3 -m pip install -q -r "$TEMP_DIR/requirements.txt" 2>/dev/null || true

# Run batch ingestion
print_info "Ingesting to collection: $RAG_COLLECTION_NAME"
python3 "$TEMP_DIR/batch_ingestion.py" \
  --folder "$LOCAL_DATA_DIR" \
  --collection-name "$RAG_COLLECTION_NAME" \
  --create_collection \
  --ingestor-host "$INGESTOR_HOST" \
  --ingestor-port "$INGESTOR_PORT" \
  --upload-batch-size "$UPLOAD_BATCH_SIZE" \
  -v

# Cleanup
rm -rf "$LOCAL_DATA_DIR" "$TEMP_DIR"
print_success "Ingestion complete"
