#!/bin/bash
# Quick status check for all VMs

PROJECT_ID="telecom5g-prod2"
ZONE="us-central1-a"

echo "🔍 Quick 5G Network Status Check"
echo "=================================="
echo ""

# Database VM
echo "📊 Database VM (MongoDB):"
gcloud compute ssh open5gs-database --zone=${ZONE} --tunnel-through-iap \
  --command "systemctl is-active mongod && mongosh open5gs --quiet --eval 'db.subscribers.countDocuments()' 2>/dev/null | tail -1 | xargs echo 'Subscribers:'" 2>/dev/null
echo ""

# Control Plane VM
echo "📊 Control Plane VM (5G Core Services):"
gcloud compute ssh open5gs-control --zone=${ZONE} --tunnel-through-iap \
  --command "systemctl is-active open5gs-{nrfd,smfd,amfd,udmd,udrd,pcfd,ausfd,nssfd,bsfd} 2>/dev/null | grep -c active | xargs echo 'Active Services:'" 2>/dev/null
echo ""

# User Plane VM
echo "📊 User Plane VM (UPF):"
gcloud compute ssh open5gs-userplane --zone=${ZONE} --tunnel-through-iap \
  --command "systemctl is-active open5gs-upfd && sudo ss -ulnp | grep ':8805' | grep -c upf | xargs echo 'UPF on port 8805:'" 2>/dev/null
echo ""

# RAN VM
echo "📊 RAN VM (UERANSIM):"
gcloud compute ssh open5gs-ran --zone=${ZONE} --tunnel-through-iap \
  --command "pgrep -f 'nr-gnb' >/dev/null && echo 'gNB: Running ✅' || echo 'gNB: Stopped ❌'; pgrep -f 'nr-ue' >/dev/null && echo 'UE: Running ✅' || echo 'UE: Stopped ❌'" 2>/dev/null
echo ""

# Connectivity test
echo "📊 Internet Connectivity:"
gcloud compute ssh open5gs-ran --zone=${ZONE} --tunnel-through-iap \
  --command "timeout 5 ping -I uesimtun0 -c 2 8.8.8.8 2>/dev/null | tail -2 | head -1" 2>/dev/null || echo "❌ Connectivity test failed"

echo ""
echo "=================================="
