#!/bin/bash
# Safe service restart with health validation

ZONE="us-central1-a"

echo "🔄 Restarting Open5GS services..."

# Restart User Plane first
echo "1️⃣ Restarting User Plane (UPF)..."
gcloud compute ssh open5gs-userplane --zone=${ZONE} --tunnel-through-iap \
  --command "sudo systemctl restart open5gs-upfd"

sleep 5

# Restart Control Plane services in correct order
echo "2️⃣ Restarting Control Plane services..."
gcloud compute ssh open5gs-control --zone=${ZONE} --tunnel-through-iap \
  --command "sudo systemctl restart open5gs-nrfd && sleep 2 && sudo systemctl restart open5gs-{amfd,smfd,udmd,udrd,pcfd,ausfd,nssfd,bsfd}"

echo "⏳ Waiting 30 seconds for services to stabilize..."
sleep 30

# Validate
echo "🔍 Running health validation..."
bash scripts/quick-status.sh

# Check PFCP association
echo "🔍 Checking SMF-UPF PFCP association..."
gcloud compute ssh open5gs-control --zone=${ZONE} --tunnel-through-iap \
  --command "sudo journalctl -u open5gs-smfd -n 20 --no-pager | grep 'PFCP associated'"

echo "✅ Service restart completed!"
