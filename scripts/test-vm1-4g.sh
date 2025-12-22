    #!/bin/bash
    # Test script for VM1 (4G Core + srsRAN)
    # Tests Open5GS EPC services, MongoDB, Node Exporter, and network connectivity

    echo "=========================================="
    echo "VM1 (4G Core) - Comprehensive Test Script"
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

    echo -n "Checking 4G subscriber in MongoDB... "
    SUBSCRIBER_COUNT=$(mongosh open5gs --eval "db.subscribers.countDocuments({imsi: '001010000000001'})" --quiet)
    if [ "$SUBSCRIBER_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ FOUND (IMSI: 001010000000001)${NC}"
        ((PASS++))
    else
        echo -e "${RED}✗ NOT FOUND${NC}"
        ((FAIL++))
    fi
    echo ""

    echo "=== Open5GS 4G EPC Services Test ==="
    test_service "open5gs-mmed"
    test_service "open5gs-hssd"
    test_service "open5gs-sgwcd"
    test_service "open5gs-sgwud"
    test_service "open5gs-pgwd"
    test_service "open5gs-pcrfd"
    echo ""

    echo "=== Open5GS WebUI Test ==="
    test_service "open5gs-webui"
    test_port 9999 "WebUI"
    test_http "http://localhost:9999" "WebUI HTTP"
    echo ""

    echo "=== Network Ports Test ==="
    test_port 36412 "MME S1-MME (SCTP)"
    test_port 2123 "GTP-C"
    test_port 2152 "GTP-U"
    test_port 9090 "Open5GS Metrics"
    echo ""

    echo "=== Monitoring Test ==="
    test_service "prometheus-node-exporter"
    test_port 9100 "Node Exporter"
    test_http "http://localhost:9100/metrics" "Node Exporter Metrics"
    test_http "http://localhost:9090/metrics" "Open5GS Metrics"
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
    echo -n "Testing ogstun interface... "
    if ip addr show ogstun > /dev/null 2>&1; then
        echo -e "${GREEN}✓ EXISTS${NC}"
        ((PASS++))
        ip addr show ogstun | grep "inet "
    else
        echo -e "${YELLOW}⚠ NOT CREATED (will be created when UE attaches)${NC}"
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

    echo "=== srsRAN Test ==="
    echo -n "Checking srsRAN installation... "
    if [ -f "/opt/srsRAN_4G/build/srsenb/src/srsenb" ]; then
        echo -e "${GREEN}✓ INSTALLED${NC}"
        ((PASS++))
        echo "  eNB binary: /opt/srsRAN_4G/build/srsenb/src/srsenb"
        echo "  UE binary: /opt/srsRAN_4G/build/srsue/src/srsue"
    else
        echo -e "${RED}✗ NOT FOUND${NC}"
        ((FAIL++))
    fi

    echo -n "Checking srsRAN config files... "
    if [ -f "/etc/srsran/enb.conf" ] && [ -f "/etc/srsran/ue.conf" ]; then
        echo -e "${GREEN}✓ CONFIGURED${NC}"
        ((PASS++))
    else
        echo -e "${RED}✗ MISSING${NC}"
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
        echo -e "${GREEN}✓ All tests passed! VM1 (4G Core) is ready.${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Start eNB: sudo /opt/srsRAN_4G/build/srsenb/src/srsenb /etc/srsran/enb.conf"
        echo "2. Start UE: sudo /opt/srsRAN_4G/build/srsue/src/srsue /etc/srsran/ue.conf"
        echo "3. Check metrics on VM3: http://<VM3-PUBLIC-IP>:3000"
        exit 0
    else
        echo -e "${RED}✗ Some tests failed. Please check the services above.${NC}"
        echo ""
        echo "Debug commands:"
        echo "- Check service logs: sudo journalctl -u open5gs-mmed -n 50"
        echo "- Check all services: systemctl status open5gs-*"
        echo "- Check MongoDB: mongosh open5gs --eval 'db.subscribers.find()'"
        exit 1
    fi
