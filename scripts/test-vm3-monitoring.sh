#!/bin/bash
# Test script for VM3 (Monitoring - Prometheus + Grafana)
# Tests Prometheus targets, Grafana, and connectivity to VM1 and VM2

echo "==========================================="
echo "VM3 (Monitoring) - Comprehensive Test Script"
echo "==========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
PASS=0
FAIL=0

# VM IPs
VM1_IP="10.10.0.10"
VM2_IP="10.10.0.20"

# Function to test service status
test_service() {
    local service_name=$1
    echo -n "Testing $service_name... "
    if systemctl is-active --quiet $service_name; then
        echo -e "${GREEN}✓ RUNNING${NC}"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗ NOT RUNNING${NC}"
        ((FAIL++))
        return 1
    fi
}

# Function to test port
test_port() {
    local port=$1
    local service=$2
    echo -n "Testing port $port ($service)... "
    if ss -tlnp | grep -q ":$port "; then
        echo -e "${GREEN}✓ LISTENING${NC}"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗ NOT LISTENING${NC}"
        ((FAIL++))
        return 1
    fi
}

# Function to test HTTP endpoint
test_http() {
    local url=$1
    local name=$2
    echo -n "Testing $name ($url)... "
    if curl -s -f -o /dev/null "$url"; then
        echo -e "${GREEN}✓ ACCESSIBLE${NC}"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗ NOT ACCESSIBLE${NC}"
        ((FAIL++))
        return 1
    fi
}

echo "=== Prometheus Test ==="
test_service "prometheus"
test_port 9090 "Prometheus"
test_http "http://localhost:9090" "Prometheus Web UI"
test_http "http://localhost:9090/-/healthy" "Prometheus Health Check"
echo ""

echo "=== Grafana Test ==="
test_service "grafana-server"
test_port 3000 "Grafana"
test_http "http://localhost:3000" "Grafana Web UI"
test_http "http://localhost:3000/api/health" "Grafana Health Check"
echo ""

echo "=== Node Exporter Test ==="
test_service "prometheus-node-exporter"
test_port 9100 "Node Exporter"
test_http "http://localhost:9100/metrics" "Node Exporter Metrics"
echo ""

echo "=== Connectivity to VM1 (4G Core) Test ==="
echo -n "Testing ping to VM1 ($VM1_IP)... "
if ping -c 3 -W 2 $VM1_IP > /dev/null 2>&1; then
    echo -e "${GREEN}✓ REACHABLE${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ UNREACHABLE${NC}"
    ((FAIL++))
fi

echo -n "Testing VM1 Node Exporter ($VM1_IP:9100)... "
if curl -s -f -o /dev/null "http://$VM1_IP:9100/metrics"; then
    echo -e "${GREEN}✓ ACCESSIBLE${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ NOT ACCESSIBLE${NC}"
    ((FAIL++))
fi

echo -n "Testing VM1 Open5GS Metrics ($VM1_IP:9090)... "
if curl -s -f -o /dev/null "http://$VM1_IP:9090/metrics"; then
    echo -e "${GREEN}✓ ACCESSIBLE${NC}"
    ((PASS++))
else
    echo -e "${YELLOW}⚠ NOT ACCESSIBLE (may not be exposed yet)${NC}"
fi
echo ""

echo "=== Connectivity to VM2 (5G Core) Test ==="
echo -n "Testing ping to VM2 ($VM2_IP)... "
if ping -c 3 -W 2 $VM2_IP > /dev/null 2>&1; then
    echo -e "${GREEN}✓ REACHABLE${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ UNREACHABLE${NC}"
    ((FAIL++))
fi

echo -n "Testing VM2 Node Exporter ($VM2_IP:9100)... "
if curl -s -f -o /dev/null "http://$VM2_IP:9100/metrics"; then
    echo -e "${GREEN}✓ ACCESSIBLE${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ NOT ACCESSIBLE${NC}"
    ((FAIL++))
fi

echo -n "Testing VM2 Open5GS Metrics ($VM2_IP:9090)... "
if curl -s -f -o /dev/null "http://$VM2_IP:9090/metrics"; then
    echo -e "${GREEN}✓ ACCESSIBLE${NC}"
    ((PASS++))
else
    echo -e "${YELLOW}⚠ NOT ACCESSIBLE (may not be exposed yet)${NC}"
fi
echo ""

echo "=== Prometheus Targets Test ==="
echo "Fetching Prometheus targets status..."
TARGETS_JSON=$(curl -s http://localhost:9090/api/v1/targets)

# Parse and display target status
echo ""
echo "Target Status:"
echo "$TARGETS_JSON" | jq -r '.data.activeTargets[] | "\(.labels.job) (\(.labels.instance)): \(.health)"' 2>/dev/null | while read line; do
    if [[ $line == *"up"* ]]; then
        echo -e "  ${GREEN}✓${NC} $line"
    else
        echo -e "  ${RED}✗${NC} $line"
    fi
done

# Count UP targets
UP_COUNT=$(echo "$TARGETS_JSON" | jq '[.data.activeTargets[] | select(.health=="up")] | length' 2>/dev/null)
TOTAL_COUNT=$(echo "$TARGETS_JSON" | jq '.data.activeTargets | length' 2>/dev/null)

echo ""
echo "Targets Summary: $UP_COUNT/$TOTAL_COUNT UP"

if [ "$UP_COUNT" -gt 0 ]; then
    ((PASS++))
else
    ((FAIL++))
fi
echo ""

echo "=== Prometheus Data Source Test (Grafana) ==="
echo -n "Testing Grafana data source connection... "
DS_TEST=$(curl -s -u admin:admin http://localhost:3000/api/datasources/proxy/1/api/v1/query?query=up 2>/dev/null)
if [[ $DS_TEST == *"success"* ]]; then
    echo -e "${GREEN}✓ CONNECTED${NC}"
    ((PASS++))
else
    echo -e "${YELLOW}⚠ NOT CONFIGURED (configure manually in Grafana)${NC}"
fi
echo ""

echo "=== System Resources Test ==="
echo -n "CPU cores: "
nproc
echo -n "Memory total: "
free -h | awk '/^Mem:/{print $2}'
echo -n "Memory available: "
free -h | awk '/^Mem:/{print $7}'
echo -n "Disk usage: "
df -h / | awk 'NR==2{print $5 " used"}'
echo ""

echo "=== Prometheus Configuration Test ==="
echo -n "Checking Prometheus config file... "
if [ -f "/etc/prometheus/prometheus.yml" ]; then
    echo -e "${GREEN}✓ EXISTS${NC}"
    ((PASS++))
    
    echo ""
    echo "Configured scrape jobs:"
    grep "job_name:" /etc/prometheus/prometheus.yml | sed 's/.*job_name:/  -/'
else
    echo -e "${RED}✗ NOT FOUND${NC}"
    ((FAIL++))
fi
echo ""

echo "==========================================="
echo "Test Summary"
echo "==========================================="
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"
TOTAL=$((PASS + FAIL))
echo "Total: $TOTAL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! VM3 (Monitoring) is ready.${NC}"
    echo ""
    echo "Access your dashboards:"
    echo "- Prometheus: http://<VM3-PUBLIC-IP>:9090"
    echo "- Grafana: http://<VM3-PUBLIC-IP>:3000 (admin/admin)"
    echo ""
    echo "Next steps:"
    echo "1. Login to Grafana and change default password"
    echo "2. Verify all targets are UP in Prometheus"
    echo "3. Create custom dashboards for 4G vs 5G comparison"
    echo "4. Run tests on VM1 and VM2 to generate traffic"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please check the services above.${NC}"
    echo ""
    echo "Debug commands:"
    echo "- Check Prometheus logs: sudo journalctl -u prometheus -n 50"
    echo "- Check Grafana logs: sudo journalctl -u grafana-server -n 50"
    echo "- Check Prometheus config: sudo cat /etc/prometheus/prometheus.yml"
    echo "- Check Prometheus targets: curl http://localhost:9090/api/v1/targets"
    exit 1
fi
