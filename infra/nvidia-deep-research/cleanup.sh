#!/bin/bash

# Clean up Terraform infrastructure
cd terraform/_LOCAL
source ./cleanup.sh

# Go back to infra directory
cd ../..

# Clean up build artifacts
echo "Cleaning up build artifacts..."
rm -rf rag opensearch .env .port-forward-*.pid 2>/dev/null || true
echo "Build artifacts cleaned up"
