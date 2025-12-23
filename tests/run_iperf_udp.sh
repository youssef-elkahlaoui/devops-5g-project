#!/bin/bash
# run_iperf_udp.sh - Measure UDP jitter and loss
# Usage: ./run_iperf_udp.sh <server_ip> <duration_seconds> <bandwidth>

SERVER_IP=$1
DURATION=$2
BANDWIDTH=$3

if [ -z "$SERVER_IP" ] || [ -z "$DURATION" ] || [ -z "$BANDWIDTH" ]; then
    echo "Usage: $0 <server_ip> <duration_seconds> <bandwidth_mbps>"
    exit 1
fi

echo "Starting UDP test to $SERVER_IP for $DURATION seconds at $BANDWIDTH Mbps..."
iperf3 -c $SERVER_IP -u -t $DURATION -b ${BANDWIDTH}M | tee iperf_udp_results.txt

# Extract jitter and loss
JITTER=$(grep "ms" iperf_udp_results.txt | awk '{print $9}')
LOSS=$(grep "%" iperf_udp_results.txt | awk '{print $12}')
echo "UDP Jitter: $JITTER ms"
echo "UDP Loss: $LOSS"