#!/bin/bash
# Start Kibana container for Elasticsearch & Kibana Remote Connection Project
# This script starts Kibana using Podman

set -e

echo "=========================================="
echo "Starting Kibana"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "ℹ $1"
}

# Check if Podman is running
echo "Checking Podman..."
if ! command -v podman &> /dev/null; then
    print_error "Podman not found. Please install Podman."
    exit 1
fi

# Check if Kibana container already exists
echo "Checking for existing Kibana container..."
if podman ps -a --format "{{.Names}}" | grep -q "^kibana$"; then
    if podman ps --format "{{.Names}}" | grep -q "^kibana$"; then
        print_warning "Kibana container is already running"
        print_info "Access Kibana at: http://localhost:5601"
        exit 0
    else
        print_info "Kibana container exists but is stopped. Starting it..."
        podman start kibana
        print_success "Kibana container started"
        print_info "Access Kibana at: http://localhost:5601"
        exit 0
    fi
fi

# Start Kibana container
echo "Starting Kibana container..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Get absolute path for Kibana config using cygpath (best practice for Git Bash)
if command -v cygpath &> /dev/null; then
    # Convert Unix path to Windows absolute path for Podman
    KIBANA_CONFIG_PATH=$(cygpath -w "$(pwd)/kibana/config/kibana.yml")
    echo "Using cygpath for path conversion"
else
    # Fallback: manual conversion from Unix to Windows path
    UNIX_PATH="$(pwd)/kibana/config/kibana.yml"
    # Convert /c/Users/... to C:\Users\...
    KIBANA_CONFIG_PATH=$(echo "$UNIX_PATH" | sed 's|^/\([a-z]\)/|\1:\\|;s|/|\\|g')
    echo "Using manual path conversion (cygpath not available)"
fi

echo "Kibana config path: $KIBANA_CONFIG_PATH"

podman run -d \
  --name kibana \
  -p 5601:5601 \
  -v "${KIBANA_CONFIG_PATH}":/usr/share/kibana/config/kibana.yml:ro \
  docker.elastic.co/kibana/kibana:8.11.0

if [ $? -eq 0 ]; then
    print_success "Kibana container started successfully"
    echo ""
    print_info "Waiting for Kibana to start (this may take 30-60 seconds)..."
    
    # Wait for Kibana to be ready
    MAX_ATTEMPTS=30
    ATTEMPT=0
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        if curl -s --connect-timeout 5 http://localhost:5601/api/status > /dev/null 2>&1; then
            print_success "Kibana is ready!"
            echo ""
            echo "Access Kibana at: http://localhost:5601"
            echo ""
            echo "To view logs: podman logs -f kibana"
            echo "To stop Kibana: podman stop kibana"
            exit 0
        fi
        ATTEMPT=$((ATTEMPT + 1))
        echo -n "."
        sleep 2
    done
    
    echo ""
    print_warning "Kibana is starting but not yet ready"
    print_info "Check logs: podman logs kibana"
    print_info "Access Kibana at: http://localhost:5601"
else
    print_error "Failed to start Kibana container"
    print_info "Check Podman logs: podman logs"
    exit 1
fi
