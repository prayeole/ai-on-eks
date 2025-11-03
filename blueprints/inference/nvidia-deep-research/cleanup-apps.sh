#!/bin/bash

#---------------------------------------------------------------
# Cleanup NVIDIA RAG & AI-Q Applications
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
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Usage: ./cleanup-apps.sh"
    echo "Removes all RAG and AI-Q applications, namespaces, and local files."
    exit 0
fi

print_warning "This will remove all RAG and AI-Q applications and local files"
read -p "Continue? (yes/no) [no]: " CONFIRM
[[ "$CONFIRM" =~ ^[Yy][Ee][Ss]$ ]] || exit 0

# Stop port-forwards
print_info "Stopping port-forwards..."
[ -f "port-forward.sh" ] && bash port-forward.sh stop all 2>/dev/null || true
for pid_file in .port-forward-*.pid; do
    [ -f "$pid_file" ] && kill $(cat "$pid_file") 2>/dev/null || true
    rm -f "$pid_file"
done

# Uninstall applications
if kubectl get namespace nv-aira &>/dev/null; then
    print_info "Uninstalling AI-Q..."
    helm uninstall aira -n nv-aira 2>/dev/null || true
    kubectl delete namespace nv-aira --timeout=60s 2>/dev/null || true
fi

if kubectl get namespace rag &>/dev/null; then
    print_info "Uninstalling RAG..."
    helm uninstall rag -n rag 2>/dev/null || true
    kubectl delete namespace rag --timeout=60s 2>/dev/null || true
fi

# Clean up local files (port-forward PIDs only)
# Note: RAG source, OpenSearch files, and .env are in infra directory
rm -f .port-forward-*.pid 2>/dev/null || true

print_success "Cleanup complete"
print_info "GPU nodes will be terminated by Karpenter in 5-10 minutes"
print_info "To clean up build artifacts (rag/, opensearch/, .env), run cleanup from infra/nvidia-deep-research/"
