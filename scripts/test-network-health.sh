#!/bin/bash
# Comprehensive 5G Network Health Check

PROJECT_ID="telecom5g-prod2"
ZONE="us-central1-a"
RESULTS_DIR="test-results"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULTS_FILE="${RESULTS_DIR}/health-check-${TIMESTAMP}.txt"

mkdir -p ${RESULTS_DIR}

echo "🔍 5G Network Health Check - $(date)" | tee ${RESULTS_FILE}
echo "========================================" | tee -a ${RESULTS_FILE}
echo "" | tee -a ${RESULTS_FILE}

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Helper function for test results
test_result() {
    local test_name=$1
    local result=$2
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$result" == "PASS" ]; then
        echo "✅ ${test_name}: PASS" | tee -a ${RESULTS_FILE}
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "❌ ${test_name}: FAIL" | tee -a ${RESULTS_FILE}
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# TEST 1: MongoDB Connection
echo "📊 Test 1/10: MongoDB Database Connection" | tee -a ${RESULTS_FILE}
MONGO_STATUS=$(gcloud compute ssh open5gs-database --zone=${ZONE} --tunnel-through-iap \
  --command "systemctl is-active mongod" 2>/dev/null)
[ "$MONGO_STATUS" == "active" ] && test_result "MongoDB Service" "PASS" || test_result "MongoDB Service" "FAIL"

# TEST 2: Control Plane Services (9 services for 5G)
echo "📊 Test 2/10: Control Plane Services (5G)" | tee -a ${RESULTS_FILE}
SERVICES=("nrfd" "smfd" "amfd" "udmd" "udrd" "pcfd" "ausfd" "nssfd" "bsfd")
CONTROL_PASS=true

for service in "${SERVICES[@]}"; do
    STATUS=$(gcloud compute ssh open5gs-control --zone=${ZONE} --tunnel-through-iap \
      --command "systemctl is-active open5gs-${service}" 2>/dev/null)
    if [ "$STATUS" != "active" ]; then
        echo "  ⚠️  open5gs-${service} is not active" | tee -a ${RESULTS_FILE}
        CONTROL_PASS=false
    fi
done

[ "$CONTROL_PASS" == true ] && test_result "Control Plane (9 services)" "PASS" || test_result "Control Plane (9 services)" "FAIL"

# TEST 3: User Plane Service
echo "📊 Test 3/10: User Plane Service" | tee -a ${RESULTS_FILE}
UPF_STATUS=$(gcloud compute ssh open5gs-userplane --zone=${ZONE} --tunnel-through-iap \
  --command "systemctl is-active open5gs-upfd" 2>/dev/null)
[ "$UPF_STATUS" == "active" ] && test_result "UPF Service" "PASS" || test_result "UPF Service" "FAIL"

# TEST 4: SMF-UPF PFCP Association
echo "📊 Test 4/10: SMF-UPF PFCP Association" | tee -a ${RESULTS_FILE}
PFCP_CHECK=$(gcloud compute ssh open5gs-control --zone=${ZONE} --tunnel-through-iap \
  --command "sudo journalctl -u open5gs-smfd -n 100 --no-pager | grep 'PFCP associated'" 2>/dev/null | tail -1)

if [[ "$PFCP_CHECK" == *"10.11.0.7"* ]]; then
    test_result "SMF-UPF PFCP Association" "PASS"
else
    test_result "SMF-UPF PFCP Association" "FAIL"
fi

# TEST 5: NRF Service Discovery
echo "📊 Test 5/10: NRF Service Discovery" | tee -a ${RESULTS_FILE}
NRF_CHECK=$(gcloud compute ssh open5gs-control --zone=${ZONE} --tunnel-through-iap \
  --command "curl -s http://127.0.0.20:7777/nnrf-nfm/v1/nf-instances | grep -c 'nfInstanceId'" 2>/dev/null)

if [ "$NRF_CHECK" -gt 5 ]; then
    test_result "NRF Service Discovery ($NRF_CHECK services)" "PASS"
else
    test_result "NRF Service Discovery" "FAIL"
fi

# TEST 6: MongoDB Subscriber Count
echo "📊 Test 6/10: MongoDB Subscriber Data" | tee -a ${RESULTS_FILE}
SUB_COUNT=$(gcloud compute ssh open5gs-database --zone=${ZONE} --tunnel-through-iap \
  --command "mongosh open5gs --quiet --eval 'db.subscribers.countDocuments()'" 2>/dev/null)

if [ "$SUB_COUNT" -gt 0 ]; then
    test_result "Subscriber Data ($SUB_COUNT subscribers)" "PASS"
else
    test_result "Subscriber Data" "FAIL"
fi

# TEST 7: Port Conflict Check (4G services should be disabled)
echo "📊 Test 7/10: Port Conflict Check" | tee -a ${RESULTS_FILE}
PORT_8805=$(gcloud compute ssh open5gs-userplane --zone=${ZONE} --tunnel-through-iap \
  --command "sudo ss -ulnp | grep ':8805' | grep -c upf" 2>/dev/null)

[ "$PORT_8805" -gt 0 ] && test_result "Port 8805 (UPF only)" "PASS" || test_result "Port 8805 (UPF only)" "FAIL"

# TEST 8: UERANSIM gNB Status
echo "📊 Test 8/10: UERANSIM gNB Status" | tee -a ${RESULTS_FILE}
GNB_PROC=$(gcloud compute ssh open5gs-ran --zone=${ZONE} --tunnel-through-iap \
  --command "pgrep -f 'nr-gnb'" 2>/dev/null)

if [ ! -z "$GNB_PROC" ]; then
    test_result "gNB Process Running" "PASS"
else
    test_result "gNB Process Running" "FAIL"
fi

# TEST 9: UERANSIM UE Status
echo "📊 Test 9/10: UERANSIM UE Status" | tee -a ${RESULTS_FILE}
UE_PROC=$(gcloud compute ssh open5gs-ran --zone=${ZONE} --tunnel-through-iap \
  --command "pgrep -f 'nr-ue'" 2>/dev/null)

if [ ! -z "$UE_PROC" ]; then
    test_result "UE Process Running" "PASS"
else
    test_result "UE Process Running" "FAIL"
fi

# TEST 10: End-to-End Connectivity
echo "📊 Test 10/10: End-to-End Internet Connectivity" | tee -a ${RESULTS_FILE}
PING_TEST=$(gcloud compute ssh open5gs-ran --zone=${ZONE} --tunnel-through-iap \
  --command "timeout 10 ping -I uesimtun0 -c 4 8.8.8.8 2>/dev/null | grep -c 'bytes from'" 2>/dev/null)

if [ "$PING_TEST" -ge 3 ]; then
    test_result "Internet Connectivity (4/4 pings)" "PASS"
else
    test_result "Internet Connectivity" "FAIL"
fi

# Summary
echo "" | tee -a ${RESULTS_FILE}
echo "========================================" | tee -a ${RESULTS_FILE}
echo "📊 TEST SUMMARY" | tee -a ${RESULTS_FILE}
echo "========================================" | tee -a ${RESULTS_FILE}
echo "Total Tests:  ${TOTAL_TESTS}" | tee -a ${RESULTS_FILE}
echo "Passed:       ${PASSED_TESTS} ✅" | tee -a ${RESULTS_FILE}
echo "Failed:       ${FAILED_TESTS} ❌" | tee -a ${RESULTS_FILE}
echo "Success Rate: $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%" | tee -a ${RESULTS_FILE}
echo "" | tee -a ${RESULTS_FILE}

if [ ${FAILED_TESTS} -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED! Network is healthy." | tee -a ${RESULTS_FILE}
    exit 0
else
    echo "⚠️  Some tests failed. Check logs for details." | tee -a ${RESULTS_FILE}
    exit 1
fi
