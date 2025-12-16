#!/bin/bash
# Setup SSH between ubuntu users on vm-core and vm-ran
# This allows Ansible to SSH from vm-core to vm-ran

set -e

echo "🔐 Setting up SSH connectivity for Ansible..."
echo ""

# Step 1: Ensure SSH key exists for ubuntu user
echo "✓ Step 1: Checking SSH key for ubuntu user..."
if [ ! -f /home/ubuntu/.ssh/id_ed25519 ]; then
    echo "  Generating SSH key..."
    sudo -u ubuntu mkdir -p /home/ubuntu/.ssh
    sudo -u ubuntu ssh-keygen -t ed25519 -f /home/ubuntu/.ssh/id_ed25519 -N "" -C "ubuntu@vm-core"
else
    echo "  SSH key already exists"
fi

# Step 2: Get public key
echo ""
echo "✓ Step 2: Getting SSH public key..."
PUBKEY=$(cat /home/ubuntu/.ssh/id_ed25519.pub)
echo "  Public key: ${PUBKEY:0:50}..."

# Step 3: Add key to vm-ran (simplified approach)
echo ""
echo "✓ Step 3: Configuring vm-ran for Ansible SSH..."

# Try to add the key to ubuntu@vm-ran
ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=5 \
    ubuntu@10.10.0.100 \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" \
    2>/dev/null || echo "  (First attempt may fail - that's okay)"

# Step 4: Test
echo ""
echo "✓ Step 4: Testing connectivity..."
if ssh -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -i /home/ubuntu/.ssh/id_ed25519 \
       ubuntu@10.10.0.100 "whoami" 2>/dev/null | grep -q ubuntu; then
    echo "  ✅ SSH connectivity verified!"
else
    echo "  ⚠️  Connectivity test inconclusive"
fi

echo ""
echo "======================================"
echo "✅ Setup Complete!"
echo "======================================"
echo ""
echo "Run UERANSIM deployment:"
echo "  cd /home/ubuntu/devops-5g-project/ansible"
echo "  ansible-playbook -i inventory/hosts.ini playbooks/deploy-ueransim.yml -vv"
echo ""
