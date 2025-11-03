#!/bin/bash

#---------------------------------------------------------------
# Deploy RAG and AI-Q Research Assistant in Parallel
#---------------------------------------------------------------

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Usage: ./deploy-all.sh"
    echo "Deploys both Enterprise RAG Blueprint and AI-Q Research Assistant in parallel."
    echo ""
    echo "This script will:"
    echo "  1. Deploy RAG Blueprint (49B Nemotron + microservices)"
    echo "  2. Deploy AI-Q Research Assistant (70B Instruct + AIRA backend) in parallel"
    echo "  3. Wait for all components to be ready"
    echo ""
    echo "Total wait time: ~25-30 minutes (vs ~35-45 minutes sequential)"
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
for var in NGC_API_KEY; do
    if [ -z "${!var}" ]; then
        print_error "Missing $var. Run ./setup-environment.sh first"
        exit 1
    fi
done

print_info "Starting parallel deployment of RAG and AI-Q..."
echo ""

# Start RAG deployment in background
print_info "Launching RAG deployment..."
(
    ./deploy-rag.sh > /tmp/deploy-rag.log 2>&1
    echo $? > /tmp/deploy-rag.exit
) &
RAG_PID=$!

# Give RAG a moment to start
sleep 2

# Start AI-Q deployment in background
print_info "Launching AI-Q deployment..."
(
    ./deploy-aira.sh > /tmp/deploy-aira.log 2>&1
    echo $? > /tmp/deploy-aira.exit
) &
AIRA_PID=$!

echo ""
print_info "Both deployments running in parallel..."
print_info "  - RAG deployment: PID $RAG_PID (logs: /tmp/deploy-rag.log)"
print_info "  - AI-Q deployment: PID $AIRA_PID (logs: /tmp/deploy-aira.log)"
echo ""
print_info "This will take approximately 25-30 minutes. You can monitor progress in separate terminals:"
echo "  tail -f /tmp/deploy-rag.log"
echo "  tail -f /tmp/deploy-aira.log"
echo ""

# Wait for both to complete
wait $RAG_PID
RAG_EXIT=$(cat /tmp/deploy-rag.exit 2>/dev/null || echo 1)

wait $AIRA_PID
AIRA_EXIT=$(cat /tmp/deploy-aira.exit 2>/dev/null || echo 1)

echo ""
echo "=================================================="

# Check results
if [ "$RAG_EXIT" -eq 0 ] && [ "$AIRA_EXIT" -eq 0 ]; then
    print_success "All deployments completed successfully!"
    echo ""
    print_info "Next steps:"
    echo "  1. Start port forwarding: cd ../../blueprints/inference/nvidia-deep-research"
    echo "  2. Access services: ./port-forward.sh start all"
    echo "  3. Visit RAG Frontend: http://localhost:3001"
    echo "  4. Visit AI-Q Frontend: http://localhost:3002"
    echo ""
    print_info "For data ingestion and usage guide, see: ../../blueprints/inference/nvidia-deep-research/README.md"

    # Cleanup temp files
    rm -f /tmp/deploy-rag.log /tmp/deploy-rag.exit /tmp/deploy-aira.log /tmp/deploy-aira.exit
    exit 0
elif [ "$RAG_EXIT" -eq 0 ]; then
    print_warning "RAG deployed successfully, but AI-Q failed"
    echo ""
    print_error "AI-Q deployment failed. Check logs:"
    echo "  cat /tmp/deploy-aira.log"
    echo ""
    print_info "You can retry AI-Q deployment separately:"
    echo "  ./deploy-aira.sh"
    exit 1
elif [ "$AIRA_EXIT" -eq 0 ]; then
    print_warning "AI-Q deployed successfully, but RAG failed"
    echo ""
    print_error "RAG deployment failed. Check logs:"
    echo "  cat /tmp/deploy-rag.log"
    echo ""
    print_info "You can retry RAG deployment separately:"
    echo "  ./deploy-rag.sh"
    exit 1
else
    print_error "Both deployments failed"
    echo ""
    echo "Check logs for details:"
    echo "  RAG: cat /tmp/deploy-rag.log"
    echo "  AI-Q: cat /tmp/deploy-aira.log"
    exit 1
fi
