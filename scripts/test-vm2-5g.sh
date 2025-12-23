#!/bin/bash
# Test script for VM2 (5G Core + UERANSIM)
# Tests Open5GS 5GC services, MongoDB, Node Exporter, UERANSIM, and network connectivity

echo "=========================================="
echo "VM2 (5G Core) - Comprehensive Test Script"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
PASS=0
FAIL=0

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

echo "=== MongoDB Test ==="
test_service "mongod"
echo -n "Testing MongoDB connectivity... "
if mongosh --eval "db.adminCommand('ping')" --quiet > /dev/null 2>&1; then
    echo -e "${GREEN}✓ CONNECTED${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAIL++))
fi

echo -n "Checking 5G subscriber in MongoDB... "
SUBSCRIBER_COUNT=$(mongosh open5gs --eval "db.subscribers.countDocuments({imsi: '999700000000001'})" --quiet)
if [ "$SUBSCRIBER_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ FOUND (IMSI: 999700000000001)${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ NOT FOUND${NC}"
    ((FAIL++))
fi
echo ""

echo "=== Open5GS 5G Core Services Test ==="
test_service "open5gs-nrfd"
test_service "open5gs-amfd"
test_service "open5gs-smfd"
test_service "open5gs-upfd"
test_service "open5gs-udmd"
test_service "open5gs-udrd"
test_service "open5gs-pcfd"
test_service "open5gs-ausfd"
test_service "open5gs-nssfd"
echo ""

echo "=== Open5GS WebUI Test ==="
test_service "open5gs-webui"
test_port 9999 "WebUI"
test_http "http://localhost:9999" "WebUI HTTP"
echo ""

echo "=== Network Ports Test ==="
test_port 38412 "AMF NGAP (SCTP)"
test_port 7777 "NRF (HTTP/2)"
test_port 8805 "UPF PFCP"
echo ""

echo "=== HTTP/2 SBI Test ==="
echo -n "Testing NRF SBI... "
if curl -s http://127.0.0.10:7777/nnrf-nfm/v1/nf-instances > /dev/null 2>&1; then
    echo -e "${GREEN}✓ ACCESSIBLE${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ NOT ACCESSIBLE${NC}"
    ((FAIL++))
fi
echo ""

echo "=== Monitoring Test ==="
test_service "prometheus-node-exporter"
test_port 9100 "Node Exporter"
test_http "http://localhost:9100/metrics" "Node Exporter Metrics"
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

echo "=== IP Forwarding Test ==="
echo -n "Testing IP forwarding... "
if sysctl net.ipv4.ip_forward | grep -q "= 1"; then
    echo -e "${GREEN}✓ ENABLED${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ DISABLED${NC}"
    ((FAIL++))
fi
echo ""

echo "=== Network Interface Test ==="
echo -n "Testing uesimtun0 interface... "
if ip addr show uesimtun0 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ EXISTS${NC}"
    ((PASS++))
    ip addr show uesimtun0 | grep "inet "
else
    echo -e "${YELLOW}⚠ NOT CREATED (will be created when UE connects)${NC}"
fi
echo ""

echo "=== Connectivity to VM3 (Monitoring) Test ==="
VM3_IP="10.10.0.30"
echo -n "Testing ping to VM3 ($VM3_IP)... "
if ping -c 3 -W 2 $VM3_IP > /dev/null 2>&1; then
    echo -e "${GREEN}✓ REACHABLE${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ UNREACHABLE${NC}"
    ((FAIL++))
fi
echo ""

echo "=== UERANSIM Test ==="
echo -n "Checking UERANSIM installation... "
if [ -f "/opt/UERANSIM/build/nr-gnb" ]; then
    echo -e "${GREEN}✓ INSTALLED${NC}"
    ((PASS++))
    echo "  gNB binary: /opt/UERANSIM/build/nr-gnb"
    echo "  UE binary: /opt/UERANSIM/build/nr-ue"
else
    echo -e "${RED}✗ NOT FOUND${NC}"
    ((FAIL++))
fi

echo -n "Checking UERANSIM config files... "
if [ -f "/etc/ueransim/gnb.yaml" ] && [ -f "/etc/ueransim/ue.yaml" ]; then
    echo -e "${GREEN}✓ CONFIGURED${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ MISSING${NC}"
    ((FAIL++))
fi
echo ""

echo "=== AMF Configuration Test ==="
echo -n "Checking AMF listens on correct IP... "
AMF_CONFIG=$(grep -A 5 "ngap:" /etc/open5gs/amf.yaml | grep "addr:" | awk '{print $3}')
if [ "$AMF_CONFIG" == "10.10.0.20" ]; then
    echo -e "${GREEN}✓ CORRECT (10.10.0.20)${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ INCORRECT ($AMF_CONFIG)${NC}"
    ((FAIL++))
fi
echo ""

echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"
TOTAL=$((PASS + FAIL))
echo "Total: $TOTAL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! VM2 (5G Core) is ready.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Start gNB: sudo /opt/UERANSIM/build/nr-gnb -c /etc/ueransim/gnb.yaml"
    echo "2. Start UE: sudo /opt/UERANSIM/build/nr-ue -c /etc/ueransim/ue.yaml"
    echo "3. Test connectivity: sudo ping -I uesimtun0 8.8.8.8"
    echo "4. Check metrics on VM3: http://<VM3-PUBLIC-IP>:3000"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please check the services above.${NC}"
    echo ""
    echo "Debug commands:"
    echo "- Check service logs: sudo journalctl -u open5gs-amfd -n 50"
    echo "- Check all services: systemctl status open5gs-*"
    echo "- Check MongoDB: mongosh open5gs --eval 'db.subscribers.find()'"
    echo "- Check NRF: curl http://127.0.0.10:7777/nnrf-nfm/v1/nf-instances"
    exit 1
fi
