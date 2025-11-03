#!/bin/bash

#---------------------------------------------------------------
# Port Forwarding Utility for RAG and AI-Q Services
#---------------------------------------------------------------

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# PID files
RAG_FRONTEND_PID=".port-forward-rag-frontend.pid"
RAG_INGESTOR_PID=".port-forward-rag-ingestor.pid"
AIRA_FRONTEND_PID=".port-forward-aira-frontend.pid"

show_help() {
    echo "Usage: ./port-forward.sh <command> [service]"
    echo ""
    echo "Commands:"
    echo "  start <service>   Start port-forwarding (rag, aira, all)"
    echo "  stop <service>    Stop port-forwarding (rag, aira, all)"
    echo "  restart <service> Restart port-forwarding (rag, aira, all)"
    echo "  status            Show status"
    echo ""
    echo "Port Mappings:"
    echo "  RAG Frontend:  localhost:3001 -> rag-frontend:3000"
    echo "  RAG Ingestor:  localhost:8082 -> ingestor-server:8082"
    echo "  AIRA Frontend: localhost:3000 -> aira-aira-frontend:3000"
}

check_port() {
    lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1
}

start_rag() {
    # RAG Frontend
    if [ -f "$RAG_FRONTEND_PID" ] && kill -0 $(cat "$RAG_FRONTEND_PID") 2>/dev/null; then
        print_info "RAG frontend already running"
    else
        if check_port 3001; then
            print_error "Port 3001 in use"
        else
            kubectl port-forward -n rag svc/rag-frontend 3001:3000 >/dev/null 2>&1 &
            echo $! > "$RAG_FRONTEND_PID"
            sleep 1
            print_success "RAG frontend: http://localhost:3001"
        fi
    fi

    # Ingestor
    if [ -f "$RAG_INGESTOR_PID" ] && kill -0 $(cat "$RAG_INGESTOR_PID") 2>/dev/null; then
        print_info "Ingestor already running"
    else
        if check_port 8082; then
            print_error "Port 8082 in use"
        else
            kubectl port-forward -n rag svc/ingestor-server 8082:8082 >/dev/null 2>&1 &
            echo $! > "$RAG_INGESTOR_PID"
            sleep 1
            print_success "Ingestor: http://localhost:8082"
        fi
    fi
}

start_aira() {
    if [ -f "$AIRA_FRONTEND_PID" ] && kill -0 $(cat "$AIRA_FRONTEND_PID") 2>/dev/null; then
        print_info "AIRA already running"
    else
        if check_port 3000; then
            print_error "Port 3000 in use"
        else
            kubectl port-forward -n nv-aira svc/aira-aira-frontend 3000:3000 >/dev/null 2>&1 &
            echo $! > "$AIRA_FRONTEND_PID"
            sleep 1
            print_success "AIRA frontend: http://localhost:3000"
        fi
    fi
}

stop_rag() {
    for pid_file in "$RAG_FRONTEND_PID" "$RAG_INGESTOR_PID"; do
        if [ -f "$pid_file" ]; then
            kill $(cat "$pid_file") 2>/dev/null || true
            rm -f "$pid_file"
        fi
    done
    print_info "RAG port-forwards stopped"
}

stop_aira() {
    if [ -f "$AIRA_FRONTEND_PID" ]; then
        kill $(cat "$AIRA_FRONTEND_PID") 2>/dev/null || true
        rm -f "$AIRA_FRONTEND_PID"
    fi
    print_info "AIRA port-forward stopped"
}

show_status() {
    echo "RAG Services:"
    [ -f "$RAG_FRONTEND_PID" ] && kill -0 $(cat "$RAG_FRONTEND_PID") 2>/dev/null && \
        print_success "Frontend: http://localhost:3001" || print_info "Frontend not running"
    [ -f "$RAG_INGESTOR_PID" ] && kill -0 $(cat "$RAG_INGESTOR_PID") 2>/dev/null && \
        print_success "Ingestor: http://localhost:8082" || print_info "Ingestor not running"

    echo ""
    echo "AI-Q Services:"
    [ -f "$AIRA_FRONTEND_PID" ] && kill -0 $(cat "$AIRA_FRONTEND_PID") 2>/dev/null && \
        print_success "Frontend: http://localhost:3000" || print_info "Frontend not running"
}

COMMAND=$1
SERVICE=$2

if [[ "$COMMAND" == "-h" ]] || [[ "$COMMAND" == "--help" ]] || [ -z "$COMMAND" ]; then
    show_help
    exit 0
fi

case "$COMMAND" in
    start)
        case "$SERVICE" in
            rag) start_rag ;;
            aira) start_aira ;;
            all) start_rag; start_aira ;;
            *) print_error "Invalid service: $SERVICE"; exit 1 ;;
        esac
        ;;
    stop)
        case "$SERVICE" in
            rag) stop_rag ;;
            aira) stop_aira ;;
            all) stop_rag; stop_aira ;;
            *) print_error "Invalid service: $SERVICE"; exit 1 ;;
        esac
        ;;
    restart)
        case "$SERVICE" in
            rag) stop_rag; sleep 1; start_rag ;;
            aira) stop_aira; sleep 1; start_aira ;;
            all) stop_rag; stop_aira; sleep 1; start_rag; start_aira ;;
            *) print_error "Invalid service: $SERVICE"; exit 1 ;;
        esac
        ;;
    status)
        show_status
        ;;
    *)
        print_error "Invalid command: $COMMAND"
        show_help
        exit 1
        ;;
esac
