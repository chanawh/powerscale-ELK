#!/bin/bash
# Test script for Elasticsearch & Kibana Remote Connection Project
# This script verifies that the setup is working correctly

set -e

echo "=========================================="
echo "Elasticsearch & Kibana Remote Connection"
echo "Test Script"
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

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo "Testing: $test_name"
    if eval "$test_command" > /dev/null 2>&1; then
        print_success "$test_name"
        ((TESTS_PASSED++))
    else
        print_error "$test_name"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Check if Elasticsearch container is running
echo "1. Checking Elasticsearch container..."
if podman ps --format "{{.Names}}" | grep -q "^elasticsearch$"; then
    print_success "Elasticsearch container is running"
    ((TESTS_PASSED++))
else
    print_error "Elasticsearch container is not running"
    print_info "Run: podman run -d --name elasticsearch --network=es-network -p 9200:9200 -e \"discovery.type=single-node\" -e \"xpack.security.enabled=false\" docker.elastic.co/elasticsearch/elasticsearch:8.11.0"
    ((TESTS_FAILED++))
fi

# Test 2: Check Elasticsearch cluster health via container
echo ""
echo "2. Checking Elasticsearch cluster health..."
ES_HEALTH=$(podman run --rm --network=es-network docker.io/curlimages/curl:latest -s http://elasticsearch:9200/_cluster/health 2>/dev/null)
ES_STATUS=$(echo $ES_HEALTH | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
echo "   Cluster status: $ES_STATUS"
if [ "$ES_STATUS" == "green" ] || [ "$ES_STATUS" == "yellow" ]; then
    print_success "Elasticsearch cluster is healthy (status: $ES_STATUS)"
    ((TESTS_PASSED++))
else
    print_error "Elasticsearch cluster status is $ES_STATUS (expected green or yellow)"
    ((TESTS_FAILED++))
fi

# Test 3: Check if Kibana is running
echo ""
echo "3. Checking Kibana container..."
if podman ps --format "{{.Names}}" | grep -q "^kibana$"; then
    print_success "Kibana container is running"
    ((TESTS_PASSED++))
else
    print_warning "Kibana container is not running"
    print_info "Start Kibana with: bash scripts/start-kibana.sh"
    ((TESTS_FAILED++))
fi

# Test 4: Check if Kibana is accessible
echo ""
echo "4. Checking Kibana accessibility..."
if curl -s --connect-timeout 5 http://localhost:5601/api/status > /dev/null 2>&1; then
    print_success "Kibana is accessible at http://localhost:5601"
    ((TESTS_PASSED++))
else
    print_warning "Kibana is not accessible"
    print_info "Ensure Kibana container is running and SSH tunnel includes port 5601"
    ((TESTS_FAILED++))
fi

# Test 5: Check Python dependencies
echo ""
echo "5. Checking Python dependencies..."
if python -c "import elasticsearch" 2>/dev/null; then
    print_success "Elasticsearch Python client is installed"
    ((TESTS_PASSED++))
else
    print_error "Elasticsearch Python client not installed"
    print_info "Run: pip install -r requirements.txt"
    ((TESTS_FAILED++))
fi

# Test 6: Test data ingestion
echo ""
echo "6. Testing data ingestion..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python "$SCRIPT_DIR/ingest_data.py"
if [ $? -eq 0 ]; then
    print_success "Data ingestion test passed"
    ((TESTS_PASSED++))
else
    print_error "Data ingestion test failed"
    ((TESTS_FAILED++))
fi

# Test 7: Verify data in Elasticsearch
echo ""
echo "7. Verifying data in Elasticsearch..."
DOC_COUNT=$(podman run --rm --network=es-network docker.io/curlimages/curl:latest -s http://elasticsearch:9200/powerscale-logs/_count 2>/dev/null | grep -o '"count":[0-9]*' | cut -d':' -f2)
if [ "$DOC_COUNT" -gt 0 ]; then
    print_success "Data verification passed ($DOC_COUNT documents in index)"
    ((TESTS_PASSED++))
else
    print_error "No documents found in powerscale-logs index"
    ((TESTS_FAILED++))
fi

# Test 8: Check if we can search the data
echo ""
echo "8. Testing search functionality..."
SEARCH_RESULT=$(podman run --rm --network=es-network docker.io/curlimages/curl:latest -s "http://elasticsearch:9200/powerscale-logs/_search?size=1" 2>/dev/null | grep -o '"total":{"value":[0-9]*' | cut -d':' -f2)
if [ "$SEARCH_RESULT" -gt 0 ]; then
    print_success "Search functionality is working"
    ((TESTS_PASSED++))
else
    print_error "Search functionality test failed"
    ((TESTS_FAILED++))
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    print_success "All tests passed! The project is working correctly."
    echo ""
    echo "You can now:"
    echo "- Access Kibana at: http://localhost:5601"
    echo "- View your data in the Discover tab"
    echo "- Create visualizations and dashboards"
    exit 0
else
    print_error "Some tests failed. Please review the errors above."
    exit 1
fi
