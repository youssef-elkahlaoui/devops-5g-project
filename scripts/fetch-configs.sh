#!/bin/bash
# Fetch all Open5GS configurations from VMs

PROJECT_ID="telecom5g-prod2"
ZONE="us-central1-a"
CONFIG_DIR="configs/open5gs"

echo "📥 Fetching Open5GS configurations from GCP VMs..."

# Create directory structure
mkdir -p ${CONFIG_DIR}/{control,userplane,database}

# Fetch Control Plane configs
echo "🔹 Fetching Control Plane configs..."
gcloud compute ssh open5gs-control --zone=${ZONE} --tunnel-through-iap \
  --command "sudo tar czf /tmp/open5gs-configs.tar.gz /etc/open5gs/*.yaml" 2>/dev/null

gcloud compute scp open5gs-control:/tmp/open5gs-configs.tar.gz \
  ${CONFIG_DIR}/control/ --zone=${ZONE} --tunnel-through-iap 2>/dev/null

cd ${CONFIG_DIR}/control && tar xzf open5gs-configs.tar.gz --strip-components=3 && rm open5gs-configs.tar.gz
cd - > /dev/null

# Fetch User Plane configs
echo "🔹 Fetching User Plane configs..."
gcloud compute ssh open5gs-userplane --zone=${ZONE} --tunnel-through-iap \
  --command "sudo tar czf /tmp/upf-configs.tar.gz /etc/open5gs/upf.yaml" 2>/dev/null

gcloud compute scp open5gs-userplane:/tmp/upf-configs.tar.gz \
  ${CONFIG_DIR}/userplane/ --zone=${ZONE} --tunnel-through-iap 2>/dev/null

cd ${CONFIG_DIR}/userplane && tar xzf upf-configs.tar.gz --strip-components=3 && rm upf-configs.tar.gz
cd - > /dev/null

# Fetch MongoDB subscriber data
echo "🔹 Fetching MongoDB subscriber data..."
gcloud compute ssh open5gs-database --zone=${ZONE} --tunnel-through-iap \
  --command "mongosh open5gs --quiet --eval 'db.subscribers.find().forEach(printjson)'" \
  > ${CONFIG_DIR}/database/subscribers-export.json 2>/dev/null

echo "✅ Configuration backup complete!"
echo "📁 Configs saved to: ${CONFIG_DIR}/"

# Show what we got
find ${CONFIG_DIR} -type f -name "*.yaml" -o -name "*.json"
