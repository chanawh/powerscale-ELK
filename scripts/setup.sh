#!/bin/bash
# Setup script for Elasticsearch & Kibana Remote Connection Project
# This script checks prerequisites and installs dependencies

set -e

echo "=========================================="
echo "Elasticsearch & Kibana Remote Connection"
echo "Setup Script"
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

# Check if running in Git Bash
if [[ ! "$OSTYPE" == "msys" ]] && [[ ! "$OSTYPE" == "win32" ]]; then
    print_warning "This script is designed for Git Bash on Windows"
    print_info "You may need to adjust commands for your environment"
fi

# Check for Python
echo "Checking Python installation..."
if command -v python &> /dev/null; then
    PYTHON_CMD="python"
    print_success "Python found: $(python --version)"
elif command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
    print_success "Python found: $(python3 --version)"
else
    print_error "Python not found. Please install Python 3 from https://python.org"
    exit 1
fi

# Check for pip
echo "Checking pip installation..."
if $PYTHON_CMD -m pip --version &> /dev/null; then
    print_success "pip found: $($PYTHON_CMD -m pip --version)"
else
    print_error "pip not found. Please install pip"
    exit 1
fi

# Check for Podman
echo "Checking Podman installation..."
if command -v podman &> /dev/null; then
    print_success "Podman found: $(podman --version)"
else
    print_error "Podman not found. Please install Podman from https://podman.io/docs/installation"
    exit 1
fi

# Check Podman machine status
echo "Checking Podman machine status..."
if podman machine list &> /dev/null; then
    print_success "Podman machine is accessible"
    podman machine list
else
    print_warning "Podman machine may not be running. Starting it..."
    podman machine start || print_error "Failed to start Podman machine"
fi

# Check for SSH
echo "Checking SSH installation..."
if command -v ssh &> /dev/null; then
    print_success "SSH found: $(ssh -V 2>&1)"
else
    print_error "SSH not found. Git Bash should include SSH"
    exit 1
fi

# Check for curl
echo "Checking curl installation..."
if command -v curl &> /dev/null; then
    print_success "curl found: $(curl --version | head -1)"
else
    print_error "curl not found. Please install curl"
    exit 1
fi

# Install Python dependencies
echo ""
echo "Installing Python dependencies..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
if [ -f "$PROJECT_DIR/requirements.txt" ]; then
    $PYTHON_CMD -m pip install -r "$PROJECT_DIR/requirements.txt"
    print_success "Python dependencies installed"
else
    print_error "requirements.txt not found at $PROJECT_DIR/requirements.txt"
    exit 1
fi

echo ""
echo "=========================================="
print_success "Setup completed successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Establish SSH tunnel:"
echo "   ssh -p 50019 -L 0.0.0.0:9200:localhost:9200 root@10.241.80.184"
echo ""
echo "2. Run the test script:"
echo "   bash scripts/test.sh"
echo ""
echo "3. Or start Kibana manually:"
echo "   bash scripts/start-kibana.sh"
echo ""
