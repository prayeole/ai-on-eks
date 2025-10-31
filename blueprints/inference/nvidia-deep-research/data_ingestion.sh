#!/bin/bash
set -e

# Configuration
S3_BUCKET_NAME="${S3_BUCKET_NAME:?Error: S3_BUCKET_NAME is required}"
INGESTOR_URL="${INGESTOR_URL:?Error: INGESTOR_URL is required}"
S3_PREFIX="${S3_PREFIX:-}"
RAG_COLLECTION_NAME="${RAG_COLLECTION_NAME:-multimodal_data}"
LOCAL_DATA_DIR="${LOCAL_DATA_DIR:-/tmp/s3_ingestion}"
UPLOAD_BATCH_SIZE="${UPLOAD_BATCH_SIZE:-100}"

# Parse INGESTOR_URL to extract host and port (expects format: host:port)
INGESTOR_HOST="${INGESTOR_URL%%:*}"
INGESTOR_PORT="${INGESTOR_URL##*:}"

# Download from S3
mkdir -p "$LOCAL_DATA_DIR"
aws s3 sync "s3://$S3_BUCKET_NAME/$S3_PREFIX" "$LOCAL_DATA_DIR" \
  --exclude "*" --include "*.pdf" --include "*.docx" --include "*.txt"

# Run batch ingestion
cd "$(dirname "$0")/rag"

# Install dependencies if needed
python3 -m pip install -q -r scripts/requirements.txt 2>/dev/null || true

python3 scripts/batch_ingestion.py \
  --folder "$LOCAL_DATA_DIR" \
  --collection-name "$RAG_COLLECTION_NAME" \
  --create_collection \
  --ingestor-host "$INGESTOR_HOST" \
  --ingestor-port "$INGESTOR_PORT" \
  --upload-batch-size "$UPLOAD_BATCH_SIZE" \
  -v

# Cleanup
rm -rf "$LOCAL_DATA_DIR"
