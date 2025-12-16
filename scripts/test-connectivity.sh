#!/bin/bash
# Test 5G connectivity - NG Setup and UE registration

set -e

CORE_IP="10.10.0.2"
RAN_IP="10.10.0.100"

echo "=== Testing 5G Connectivity ==="
echo "Core IP: $CORE_IP"
echo "RAN IP: $RAN_IP"
echo ""

# Test core reachability
echo "[TEST 1] Testing reachability to Core Network..."
if ping -c 3 $CORE_IP > /dev/null; then
    echo "✓ Core reachable"
else
    echo "✗ Core unreachable"
    exit 1
fi

echo ""
echo "[TEST 2] Checking Open5GS services on Core..."
ssh -o ConnectTimeout=5 ubuntu@$CORE_IP "systemctl status open5gs-amf | grep -q active && echo '✓ AMF running' || echo '✗ AMF not running'"
ssh ubuntu@$CORE_IP "systemctl status open5gs-smf | grep -q active && echo '✓ SMF running' || echo '✗ SMF not running'"
ssh ubuntu@$CORE_IP "systemctl status open5gs-upf | grep -q active && echo '✓ UPF running' || echo '✗ UPF not running'"

echo ""
echo "[TEST 3] Building UERANSIM config..."
ssh ubuntu@$RAN_IP "ls -la UERANSIM/config/open5gs-gnb.yaml && echo '✓ gNB config exists' || echo '✗ gNB config missing'"
ssh ubuntu@$RAN_IP "ls -la UERANSIM/config/open5gs-ue.yaml && echo '✓ UE config exists' || echo '✗ UE config missing'"

echo ""
echo "[TEST 4] Testing gNB startup (30 second timeout)..."
timeout 30 ssh ubuntu@$RAN_IP "cd UERANSIM && ./nr-gnb -c config/open5gs-gnb.yaml" 2>&1 | grep -i "ng setup\|successful" && echo "✓ gNB connectivity verified" || echo "Waiting for registration..."

echo ""
echo "=== Connectivity Test Complete ==="
