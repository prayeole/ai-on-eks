#!/bin/bash

# Clean up Terraform infrastructure
cd terraform/_LOCAL
source ./cleanup.sh

# Go back to infra directory
cd ../..

# Clean up configuration
echo "Cleaning up configuration files..."
rm -f .env 2>/dev/null || true
rm -rf /tmp/.port-forward-*.pid 2>/dev/null || true
echo "Configuration cleaned up"

echo ""
echo "============================================"
echo "Manual cleanup required:"
echo "  - rag/        (RAG source code)"
echo "  - opensearch/ (OpenSearch integration files)"
echo ""
echo "To remove these directories, run:"
echo "  rm -rf rag opensearch"
echo "============================================"
