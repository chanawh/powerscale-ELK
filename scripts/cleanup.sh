#!/bin/bash
# Cleanup script for Elasticsearch & Kibana Remote Connection
# This script stops containers, removes data, and cleans up resources

set -e

echo "=========================================="
echo "Elasticsearch & Kibana Remote Connection"
echo "Cleanup Script"
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

# Warning message
echo "WARNING: This script will:"
echo "  1. Stop and remove Kibana container"
echo "  2. Delete all data from the powerscale-logs index"
echo "  3. Remove the powerscale-logs index"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# Step 1: Stop and remove Kibana container
echo "1. Stopping Kibana container..."
if podman ps --format "{{.Names}}" | grep -q "^kibana$"; then
    podman stop kibana
    print_success "Kibana container stopped"
else
    print_info "Kibana container is not running"
fi

echo ""
echo "2. Removing Kibana container..."
if podman ps -a --format "{{.Names}}" | grep -q "^kibana$"; then
    podman rm -f kibana
    print_success "Kibana container removed"
else
    print_info "Kibana container does not exist"
fi

# Step 2: Delete data from Elasticsearch
echo ""
echo "3. Checking Elasticsearch connection..."
if curl -s --connect-timeout 5 http://localhost:9200/_cluster/health > /dev/null 2>&1; then
    print_success "Elasticsearch is accessible"
    
    echo ""
    echo "4. Checking for powerscale-logs index..."
    if curl -s http://localhost:9200/powerscale-logs | grep -q "index_found"; then
        print_info "powerscale-logs index exists"
        
        echo ""
        echo "5. Deleting powerscale-logs index..."
        curl -X DELETE "http://localhost:9200/powerscale-logs" > /dev/null 2>&1
        print_success "powerscale-logs index deleted"
    else
        print_info "powerscale-logs index does not exist"
    fi
else
    print_warning "Elasticsearch is not accessible. Skipping data cleanup."
    print_info "If you want to clean up remote data, ensure SSH tunnel is active."
fi

# Step 3: Clean up Podman resources (optional)
echo ""
echo "6. Cleaning up Podman resources..."
read -p "Do you want to remove all stopped containers and dangling images? (yes/no): " podman_cleanup

if [ "$podman_cleanup" == "yes" ]; then
    # Remove stopped containers
    STOPPED_CONTAINERS=$(podman ps -aq --filter "status=exited")
    if [ -n "$STOPPED_CONTAINERS" ]; then
        podman rm $STOPPED_CONTAINERS
        print_success "Removed stopped containers"
    else
        print_info "No stopped containers to remove"
    fi
    
    # Remove dangling images
    DANGLING_IMAGES=$(podman images -f dangling=true -q)
    if [ -n "$DANGLING_IMAGES" ]; then
        podman rmi $DANGLING_IMAGES
        print_success "Removed dangling images"
    else
        print_info "No dangling images to remove"
    fi
else
    print_info "Skipping Podman resource cleanup"
fi

# Step 4: Clean up Python cache
echo ""
echo "7. Cleaning up Python cache..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
if [ -d "$PROJECT_DIR/__pycache__" ]; then
    rm -rf "$PROJECT_DIR/__pycache__"
    print_success "Python cache removed"
else
    print_info "No Python cache to remove"
fi

if [ -d "$PROJECT_DIR/scripts/__pycache__" ]; then
    rm -rf "$PROJECT_DIR/scripts/__pycache__"
    print_success "Scripts Python cache removed"
else
    print_info "No scripts Python cache to remove"
fi

# Summary
echo ""
echo "=========================================="
print_success "Cleanup completed successfully!"
echo "=========================================="
echo ""
echo "What was cleaned up:"
echo "  ✓ Kibana container stopped and removed"
echo "  ✓ powerscale-logs index deleted (if it existed)"
echo "  ✓ Python cache removed"
if [ "$podman_cleanup" == "yes" ]; then
    echo "  ✓ Stopped containers removed"
    echo "  ✓ Dangling images removed"
fi
echo ""
echo "Note: SSH tunnel is still active if you started it."
echo "      You can close it by pressing Ctrl+C in the terminal where it's running."
echo ""
echo "To start fresh, run:"
echo "  1. bash scripts/setup.sh"
echo "  2. ssh -p 50019 -L 0.0.0.0:9200:localhost:9200 root@10.241.80.184"
echo "  3. bash scripts/test.sh"
echo ""
