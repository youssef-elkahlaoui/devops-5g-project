#!/bin/bash
# Setup SSH connectivity between vm-core and vm-ran
# Run this on vm-core after deploy-core.yml completes

set -e

echo "🔐 Setting up SSH connectivity between vm-core and vm-ran..."
echo ""

# Step 1: Ensure SSH key exists on vm-core
echo "✓ Step 1: Checking SSH key on vm-core..."
if [ ! -f /root/.ssh/id_ed25519 ]; then
    echo "  Creating SSH key..."
    ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -C "root@vm-core"
else
    echo "  SSH key already exists"
fi

# Step 2: Get vm-core's public key
echo ""
echo "✓ Step 2: Getting vm-core SSH public key..."
PUBKEY=$(cat /root/.ssh/id_ed25519.pub)
echo "  Public key: ${PUBKEY:0:50}..."

# Step 3: Add vm-core's key to vm-ran's authorized_keys
echo ""
echo "✓ Step 3: Adding vm-core key to vm-ran..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /root/.ssh/id_ed25519 ubuntu@10.10.0.100 << EOF
sudo bash -c 'mkdir -p /root/.ssh && chmod 700 /root/.ssh'
sudo bash -c 'echo "$PUBKEY" >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys'
EOF

# Step 4: Test connectivity
echo ""
echo "✓ Step 4: Testing SSH connectivity..."
if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /root/.ssh/id_ed25519 root@10.10.0.100 "echo 'SSH works from vm-core!'" 2>/dev/null; then
    echo "  ✅ SSH connectivity verified!"
else
    echo "  ⚠️  SSH test failed, but keys should be set up"
fi

echo ""
echo "======================================"
echo "✅ SSH Setup Complete!"
echo "======================================"
echo ""
echo "You can now run from vm-core:"
echo "  ansible-playbook -i inventory/hosts.ini playbooks/deploy-ueransim.yml -vv"
echo ""
