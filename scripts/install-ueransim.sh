#!/bin/bash
# UERANSIM Installation Script for RAN Simulator VM

set -e

echo "=== Updating system ==="
sudo apt update && sudo apt upgrade -y

echo "=== Installing build dependencies ==="
sudo apt install -y make g++ libsctp-dev lksctp-tools iproute2

echo "=== Installing cmake ==="
sudo snap install cmake --classic

echo "=== Cloning UERANSIM ==="
cd ~
git clone https://github.com/aligungr/UERANSIM
cd UERANSIM

echo "=== Building UERANSIM ==="
make

echo "=== Copying configuration files ==="
# Copy the pre-configured files if they exist
if [ -f /tmp/open5gs-gnb.yaml ]; then
    cp /tmp/open5gs-gnb.yaml config/open5gs-gnb.yaml
fi

if [ -f /tmp/open5gs-ue.yaml ]; then
    cp /tmp/open5gs-ue.yaml config/open5gs-ue.yaml
fi

echo "✅ UERANSIM built successfully"
echo ""
echo "To start gNB:"
echo "  cd ~/UERANSIM && ./build/nr-gnb -c config/open5gs-gnb.yaml"
echo ""
echo "To start UE (in another terminal):"
echo "  cd ~/UERANSIM && sudo ./build/nr-ue -c config/open5gs-ue.yaml"
echo ""
echo "To test connectivity:"
echo "  ping -I uesimtun0 8.8.8.8"
