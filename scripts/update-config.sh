#!/bin/bash
# Safe configuration update with validation and rollback

if [ $# -lt 2 ]; then
    echo "Usage: $0 <vm-name> <config-file>"
    echo "Example: $0 open5gs-control smf.yaml"
    exit 1
fi

VM_NAME=$1
CONFIG_FILE=$2
ZONE="us-central1-a"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "🔧 Updating configuration on ${VM_NAME}..."

# Step 1: Backup current config
echo "📦 Creating backup..."
gcloud compute ssh ${VM_NAME} --zone=${ZONE} --tunnel-through-iap \
  --command "sudo cp /etc/open5gs/${CONFIG_FILE} /etc/open5gs/${CONFIG_FILE}.backup-${TIMESTAMP}"

# Step 2: Validate new config syntax
echo "🔍 Validating YAML syntax..."
python3 -c "import yaml; yaml.safe_load(open('configs/open5gs/control/${CONFIG_FILE}'))" || {
    echo "❌ YAML syntax error! Aborting."
    exit 1
}

# Step 3: Upload new config
echo "📤 Uploading new configuration..."
gcloud compute scp configs/open5gs/control/${CONFIG_FILE} \
  ${VM_NAME}:/tmp/ --zone=${ZONE} --tunnel-through-iap

# Step 4: Apply config
echo "✅ Applying configuration..."
gcloud compute ssh ${VM_NAME} --zone=${ZONE} --tunnel-through-iap \
  --command "sudo cp /tmp/${CONFIG_FILE} /etc/open5gs/ && sudo chown root:root /etc/open5gs/${CONFIG_FILE}"

# Step 5: Restart relevant service
SERVICE_NAME=$(echo ${CONFIG_FILE} | sed 's/.yaml/d/')
echo "🔄 Restarting open5gs-${SERVICE_NAME}..."
gcloud compute ssh ${VM_NAME} --zone=${ZONE} --tunnel-through-iap \
  --command "sudo systemctl restart open5gs-${SERVICE_NAME}"

# Step 6: Verify service started
sleep 5
STATUS=$(gcloud compute ssh ${VM_NAME} --zone=${ZONE} --tunnel-through-iap \
  --command "systemctl is-active open5gs-${SERVICE_NAME}")

if [ "$STATUS" == "active" ]; then
    echo "✅ Configuration update successful!"
    echo "📋 Backup saved as: ${CONFIG_FILE}.backup-${TIMESTAMP}"
else
    echo "❌ Service failed to start! Rolling back..."
    gcloud compute ssh ${VM_NAME} --zone=${ZONE} --tunnel-through-iap \
      --command "sudo cp /etc/open5gs/${CONFIG_FILE}.backup-${TIMESTAMP} /etc/open5gs/${CONFIG_FILE} && sudo systemctl restart open5gs-${SERVICE_NAME}"
    echo "⚠️  Rollback completed. Check logs for errors."
    exit 1
fi

# Step 7: Commit to Git
echo "📝 Committing changes to Git..."
git add configs/open5gs/control/${CONFIG_FILE}
git commit -m "Update ${CONFIG_FILE} on ${VM_NAME}"
git push

echo "🎉 Configuration update completed and version controlled!"
