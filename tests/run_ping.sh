#!/bin/bash
# run_ping.sh - Measure RTT between VMs
# Usage: ./run_ping.sh <target_ip> <duration_seconds>

TARGET_IP=$1
DURATION=$2

if [ -z "$TARGET_IP" ] || [ -z "$DURATION" ]; then
    echo "Usage: $0 <target_ip> <duration_seconds>"
    exit 1
fi

echo "Starting ping test to $TARGET_IP for $DURATION seconds..."
ping -c $DURATION $TARGET_IP | tee ping_results.txt

# Extract average RTT
AVG_RTT=$(tail -1 ping_results.txt | awk -F'/' '{print $5}')
echo "Average RTT: $AVG_RTT ms"