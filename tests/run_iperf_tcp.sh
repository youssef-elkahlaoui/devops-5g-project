#!/bin/bash
# run_iperf_tcp.sh - Measure TCP throughput
# Usage: ./run_iperf_tcp.sh <server_ip> <duration_seconds>

SERVER_IP=$1
DURATION=$2

if [ -z "$SERVER_IP" ] || [ -z "$DURATION" ]; then
    echo "Usage: $0 <server_ip> <duration_seconds>"
    exit 1
fi

echo "Starting TCP throughput test to $SERVER_IP for $DURATION seconds..."
iperf3 -c $SERVER_IP -t $DURATION | tee iperf_tcp_results.txt

# Extract bandwidth
BANDWIDTH=$(grep "sender" iperf_tcp_results.txt | awk '{print $7 " " $8}')
echo "TCP Bandwidth: $BANDWIDTH"