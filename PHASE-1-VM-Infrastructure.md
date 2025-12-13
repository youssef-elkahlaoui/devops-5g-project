# PHASE 1: Infrastructure & Core Network Deployment (VM-Based)

**⏱️ Duration: 5-6 Hours | 🎯 Goal: Complete 4G and 5G core network on GCP VMs**

---

## 📋 Phase 1 Overview

In this phase, you will:

1. Set up GCP project with custom VPC and security rules
2. Provision 5 Virtual Machines for different network functions
3. Install and configure MongoDB 8.0 database
4. Deploy complete 4G EPC network (MME, HSS, PCRF, SGW, PGW)
5. Deploy complete 5G SA Core network (AMF, SMF, UPF, NRF, UDM, PCF, AUSF, NSSF)
6. Configure networking (SCTP bindings, GTP-U, NAT rules)
7. Deploy WebUI for subscriber management

**Result:** Fully functional 4G and 5G core networks ready for testing

---

## ✅ Prerequisites Verification

Before starting, verify you have:

```bash
# Check Google Cloud SDK
gcloud --version
# Expected: Google Cloud SDK 450.0.0+

# Check authentication
gcloud auth list
# Expected: Your email marked as ACTIVE

# Verify local tools
python3 --version    # >= 3.10
git --version        # Any recent version
```

---

## 🔧 STEP 1: GCP Project Setup (30 minutes)

### 1.1 Authenticate and Set Project

```bash
# Login to Google Cloud
gcloud auth login

# Create new project (or use existing)
export PROJECT_ID="telecom5g-prod2"  # Change to your project ID
gcloud projects create $PROJECT_ID --name="Open5GS 4G/5G Deployment"

# Set as active project
gcloud config set project $PROJECT_ID

# Link billing account
BILLING_ACCOUNT=$(gcloud billing accounts list --format="value(ACCOUNT_ID)" | head -n 1)
gcloud billing projects link $PROJECT_ID --billing-account=$BILLING_ACCOUNT

# Verify project is set
gcloud config get-value project
```

### 1.2 Enable Required APIs

```bash
# Enable all necessary GCP APIs
gcloud services enable compute.googleapis.com \
  servicenetworking.googleapis.com \
  cloudresourcemanager.googleapis.com \
  oslogin.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com

# Verify APIs are enabled
gcloud services list --enabled | grep -E "compute|servicenetworking"
```

### 1.3 Set Default Region and Zone

```bash
# Set region and zone (choose closest to your location)
export REGION="us-central1"
export ZONE="us-central1-a"

gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

echo "✅ GCP project configured: $PROJECT_ID in $REGION"
```

---

## 🌐 STEP 2: Network Infrastructure (45 minutes)

### 2.1 Create Custom VPC

```bash
# Create custom VPC network
gcloud compute networks create open5gs-vpc \
  --subnet-mode=custom \
  --bgp-routing-mode=regional \
  --description="Open5GS Core Network VPC"

echo "✅ VPC created: open5gs-vpc"
```

### 2.2 Create Subnets

```bash
# Control Plane Subnet (for MME, AMF, SMF, NRF, DB)
gcloud compute networks subnets create control-subnet \
  --network=open5gs-vpc \
  --region=$REGION \
  --range=10.10.0.0/24 \
  --description="Control Plane and Signaling"

# User Plane Subnet (for UPF, SGW-U)
gcloud compute networks subnets create data-subnet \
  --network=open5gs-vpc \
  --region=$REGION \
  --range=10.11.0.0/24 \
  --description="User Plane Data Traffic"

# Verify subnets
gcloud compute networks subnets list --network=open5gs-vpc
```

### 2.3 Configure Firewall Rules

```bash
# Allow SSH from anywhere (restrict in production)
gcloud compute firewall-rules create open5gs-allow-ssh \
  --network=open5gs-vpc \
  --allow=tcp:22 \
  --source-ranges=0.0.0.0/0 \
  --description="Allow SSH access"

# Allow SCTP for S1-MME (4G) and NGAP (5G)
gcloud compute firewall-rules create open5gs-allow-sctp \
  --network=open5gs-vpc \
  --allow=sctp:36412,sctp:38412 \
  --source-ranges=10.10.0.0/24,10.11.0.0/24 \
  --description="Allow SCTP for MME and AMF"

# Allow GTP-U for user plane traffic
gcloud compute firewall-rules create open5gs-allow-gtpu \
  --network=open5gs-vpc \
  --allow=udp:2152 \
  --source-ranges=10.10.0.0/24,10.11.0.0/24 \
  --description="Allow GTP-U for UPF and SGW"

# Allow HTTP/2 for 5G SBI (Service Based Interface)
gcloud compute firewall-rules create open5gs-allow-sbi \
  --network=open5gs-vpc \
  --allow=tcp:7777 \
  --source-ranges=10.10.0.0/24 \
  --description="Allow HTTP/2 SBI communication"

# Allow Diameter for 4G (S6a, Gx interfaces)
gcloud compute firewall-rules create open5gs-allow-diameter \
  --network=open5gs-vpc \
  --allow=tcp:3868,sctp:3868 \
  --source-ranges=10.10.0.0/24 \
  --description="Allow Diameter protocol"

# Allow WebUI access
gcloud compute firewall-rules create open5gs-allow-webui \
  --network=open5gs-vpc \
  --allow=tcp:9999 \
  --source-ranges=0.0.0.0/0 \
  --description="Allow Open5GS WebUI access"

# Allow MongoDB
gcloud compute firewall-rules create open5gs-allow-mongodb \
  --network=open5gs-vpc \
  --allow=tcp:27017 \
  --source-ranges=10.10.0.0/24 \
  --description="Allow MongoDB access"

# Allow Prometheus/Grafana
gcloud compute firewall-rules create open5gs-allow-monitoring \
  --network=open5gs-vpc \
  --allow=tcp:9090,tcp:3000 \
  --source-ranges=0.0.0.0/0 \
  --description="Allow monitoring access"

# Allow internal communication
gcloud compute firewall-rules create open5gs-allow-internal \
  --network=open5gs-vpc \
  --allow=tcp,udp,icmp \
  --source-ranges=10.10.0.0/24,10.11.0.0/24 \
  --description="Allow all internal communication"

# List all firewall rules
gcloud compute firewall-rules list --filter="network:open5gs-vpc"

echo "✅ Firewall rules configured"
```

---

## 💻 STEP 3: Virtual Machine Provisioning (30 minutes)

### 3.1 Create Database VM

```bash
# MongoDB Database VM
gcloud compute instances create open5gs-db \
  --zone=$ZONE \
  --machine-type=e2-medium \
  --subnet=control-subnet \
  --private-network-ip=10.10.0.4 \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB \
  --boot-disk-type=pd-standard \
  --tags=database,open5gs

echo "✅ Database VM created: open5gs-db (10.10.0.4)"
```

### 3.2 Create Control Plane VM

```bash
# Control Plane VM (MME, AMF, SMF, NRF, HSS, UDM, PCF, AUSF, PCRF)
gcloud compute instances create open5gs-control \
  --zone=$ZONE \
  --machine-type=n2-standard-4 \
  --subnet=control-subnet \
  --private-network-ip=10.10.0.2 \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB \
  --boot-disk-type=pd-ssd \
  --tags=control-plane,open5gs

echo "✅ Control Plane VM created: open5gs-control (10.10.0.2)"
```

### 3.3 Create User Plane VM

```bash
# User Plane VM (UPF, SGW-U, PGW-U) - Compute optimized for packet processing
gcloud compute instances create open5gs-userplane \
  --zone=$ZONE \
  --machine-type=c2-standard-4 \
  --subnet=data-subnet \
  --private-network-ip=10.11.0.7 \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB \
  --boot-disk-type=pd-ssd \
  --tags=user-plane,open5gs \
  --can-ip-forward

echo "✅ User Plane VM created: open5gs-userplane (10.11.0.7)"
```

### 3.4 Create Monitoring VM

```bash
# Monitoring VM (Prometheus, Grafana, WebUI)
gcloud compute instances create open5gs-monitoring \
  --zone=$ZONE \
  --machine-type=e2-standard-2 \
  --subnet=control-subnet \
  --private-network-ip=10.10.0.50 \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB \
  --boot-disk-type=pd-standard \
  --tags=monitoring,open5gs

echo "✅ Monitoring VM created: open5gs-monitoring (10.10.0.50)"
```

### 3.5 Create RAN Simulator VM

```bash
# RAN Simulator VM (UERANSIM - eNB, gNB, UEs)
gcloud compute instances create open5gs-ran \
  --zone=$ZONE \
  --machine-type=n2-standard-2 \
  --subnet=control-subnet \
  --private-network-ip=10.10.0.100 \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=30GB \
  --boot-disk-type=pd-standard \
  --tags=ran-simulator,open5gs

echo "✅ RAN Simulator VM created: open5gs-ran (10.10.0.100)"
```

### 3.6 Verify All VMs

```bash
# List all instances
gcloud compute instances list --filter="name~open5gs"

# Expected output:
# NAME                  ZONE           MACHINE_TYPE   INTERNAL_IP   EXTERNAL_IP    STATUS
# open5gs-db            us-central1-a  e2-medium      10.10.0.4     x.x.x.x        RUNNING
# open5gs-control       us-central1-a  n2-standard-4  10.10.0.2     x.x.x.x        RUNNING
# open5gs-userplane     us-central1-a  c2-standard-4  10.11.0.7     x.x.x.x        RUNNING
# open5gs-monitoring    us-central1-a  e2-standard-2  10.10.0.50    x.x.x.x        RUNNING
# open5gs-ran           us-central1-a  n2-standard-2  10.10.0.100   x.x.x.x        RUNNING
```

---

## 🗄️ STEP 4: MongoDB Database Setup (20 minutes)

**Reference:** [Open5GS Docs - MongoDB Installation](https://open5gs.org/open5gs/docs/guide/01-quickstart/)

### 4.1 SSH into Database VM

```bash
# SSH into database VM
gcloud compute ssh open5gs-db --zone=$ZONE
```

### 4.2 Install MongoDB 8.0

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y gnupg curl

# Import MongoDB GPG key
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
  sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor

# Add MongoDB repository
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list

# Update package list
sudo apt update

# Install MongoDB
sudo apt install -y mongodb-org

# Verify installation
mongod --version
```

### 4.3 Configure MongoDB for Remote Access

```bash
# Backup original configuration
sudo cp /etc/mongod.conf /etc/mongod.conf.backup

# Edit MongoDB configuration
sudo nano /etc/mongod.conf
```

**Change the `bindIp` setting:**

```yaml
# network interfaces
net:
  port: 27017
  bindIp: 0.0.0.0 # Change from 127.0.0.1 to allow remote connections
```

**Save and exit** (Ctrl+O, Enter, Ctrl+X)

### 4.4 Start MongoDB Service

```bash
# Enable MongoDB to start on boot
sudo systemctl enable mongod

# Start MongoDB service
sudo systemctl start mongod

# Check status
sudo systemctl status mongod

# Verify MongoDB is listening
sudo ss -tlnp | grep 27017

# Test local connection
mongosh --eval "db.adminCommand('ping')"

echo "✅ MongoDB 8.0 installed and configured"
```

### 4.5 Exit Database VM

```bash
exit
```

---

## 📡 STEP 5: Open5GS Installation & Configuration (60 minutes)

**Reference:** [Open5GS Docs - Installation](https://open5gs.org/open5gs/docs/guide/01-quickstart/)

### 5.1 SSH into Control Plane VM

```bash
gcloud compute ssh open5gs-control --zone=$ZONE
```

### 5.2 Install Open5GS

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Add Open5GS PPA repository
sudo add-apt-repository -y ppa:open5gs/latest
sudo apt update

# Install Open5GS (installs all components)
sudo apt install -y open5gs

# Verify installation
dpkg -l | grep open5gs

echo "✅ Open5GS installed"
```

### 5.3 QUICK CONFIG - All Changes in One Script (RECOMMENDED)

**For a faster setup, run this single script that applies ALL required changes:**

```bash
# Apply all configuration changes with one script
cat > ~/configure-open5gs.sh << 'SCRIPT'
#!/bin/bash
echo "Configuring Open5GS for multi-VM deployment..."

# Control Plane configs (this VM = 10.10.0.2)
# User Plane VM = 10.11.0.7
# Database VM = 10.10.0.4

# 4G MME - change S1AP address
sudo sed -i 's/127.0.0.2/10.10.0.2/g' /etc/open5gs/mme.yaml

# 4G SGW-C - point to User Plane VM for SGW-U
sudo sed -i 's/127.0.0.6/10.11.0.7/g' /etc/open5gs/sgwc.yaml

# SMF - point to User Plane VM for UPF
sudo sed -i 's/127.0.0.7/10.11.0.7/g' /etc/open5gs/smf.yaml

# 5G AMF - change NGAP address
sudo sed -i 's/127.0.0.5/10.10.0.2/g' /etc/open5gs/amf.yaml

# All MongoDB connections - point to Database VM
for file in hss.yaml pcrf.yaml udr.yaml pcf.yaml bsf.yaml; do
  sudo sed -i 's/127.0.0.1\/open5gs/10.10.0.4\/open5gs/g' /etc/open5gs/$file
done

echo "✅ All configurations updated!"
echo "Now restart services..."

# Restart all services
sudo systemctl restart open5gs-mmed open5gs-hssd open5gs-pcrfd open5gs-sgwcd open5gs-smfd
sleep 3
sudo systemctl restart open5gs-nrfd
sleep 3
sudo systemctl restart open5gs-amfd open5gs-udmd open5gs-udrd open5gs-pcfd open5gs-ausfd open5gs-nssfd open5gs-bsfd

# Enable all on boot
sudo systemctl enable open5gs-mmed open5gs-hssd open5gs-pcrfd open5gs-sgwcd open5gs-smfd
sudo systemctl enable open5gs-nrfd open5gs-amfd open5gs-udmd open5gs-udrd open5gs-pcfd open5gs-ausfd open5gs-nssfd open5gs-bsfd

echo "✅ All services restarted and enabled!"
SCRIPT

chmod +x ~/configure-open5gs.sh
~/configure-open5gs.sh
```

### 5.4 Verify Services Are Running

```bash
# Check all services
echo "=== Control Plane Services ==="
for svc in mmed hssd pcrfd sgwcd smfd nrfd amfd udmd udrd pcfd ausfd nssfd bsfd; do
  status=$(systemctl is-active open5gs-$svc)
  echo "open5gs-$svc: $status"
done

# Verify key ports are listening
echo ""
echo "=== Port Verification ==="
sudo ss -tlnp | grep -E "36412|38412|7777"
```

### 5.5 Exit Control Plane VM

```bash
exit
```

---

## 📊 STEP 6: User Plane Configuration (30 minutes)

### 6.1 SSH into User Plane VM

```bash
gcloud compute ssh open5gs-userplane --zone=$ZONE
```

### 6.2 Install Open5GS on User Plane VM

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Add Open5GS PPA repository
sudo add-apt-repository -y ppa:open5gs/latest
sudo apt update

# Install Open5GS (only need UPF and SGW-U components)
sudo apt install -y open5gs

echo "✅ Open5GS installed on User Plane VM"
```

### 6.3 Configure User Plane (Quick Script)

```bash
# Apply all User Plane configuration with one script
cat > ~/configure-userplane.sh << 'SCRIPT'
#!/bin/bash
echo "Configuring User Plane for multi-VM deployment..."

# This VM = 10.11.0.7

# UPF - change GTP-U address
sudo sed -i 's/127.0.0.7/10.11.0.7/g' /etc/open5gs/upf.yaml

# SGW-U - change GTP-U address
sudo sed -i 's/127.0.0.6/10.11.0.7/g' /etc/open5gs/sgwu.yaml

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure NAT for UE traffic
sudo iptables -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -s 10.46.0.0/16 ! -o ogstun -j MASQUERADE
sudo iptables -I INPUT -i ogstun -j ACCEPT
sudo iptables -I FORWARD -i ogstun -j ACCEPT
sudo iptables -I FORWARD -o ogstun -j ACCEPT

# Save iptables
sudo apt install -y iptables-persistent
sudo netfilter-persistent save

# Restart and enable services
sudo systemctl restart open5gs-upfd open5gs-sgwud
sudo systemctl enable open5gs-upfd open5gs-sgwud

echo "✅ User Plane configured!"
SCRIPT

chmod +x ~/configure-userplane.sh
~/configure-userplane.sh
```

### 6.4 Verify User Plane Services

```bash
# Check services
sudo systemctl status open5gs-upfd --no-pager
sudo systemctl status open5gs-sgwud --no-pager

# Verify GTP-U port 2152 is listening
sudo ss -ulnp | grep 2152

# Check ogstun interface is created
ip addr show ogstun

echo "✅ User Plane ready"
```

### 6.5 Exit User Plane VM

```bash
exit
```

---

## 🌐 STEP 7: WebUI Deployment (30 minutes)

**Reference:** [Open5GS Docs - WebUI](https://open5gs.org/open5gs/docs/guide/01-quickstart/)

### 7.1 SSH into Monitoring VM

```bash
gcloud compute ssh open5gs-monitoring --zone=$ZONE
```

### 7.2 Install Node.js and WebUI

```bash
# Update system and install Node.js 20.x
sudo apt update && sudo apt upgrade -y
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install WebUI
curl -fsSL https://open5gs.org/open5gs/assets/webui/install | sudo -E bash -

# Configure MongoDB connection
echo "DB_URI=mongodb://10.10.0.4/open5gs" | sudo tee /etc/default/open5gs-webui

# Start WebUI
sudo systemctl restart open5gs-webui
sudo systemctl enable open5gs-webui

# Get access URL
EXTERNAL_IP=$(curl -s ifconfig.me)
echo "WebUI: http://${EXTERNAL_IP}:9999 | Login: admin / 1423"
```

### 7.3 Exit Monitoring VM

```bash
exit
```

---

## 👤 STEP 8: Register Test Subscribers (15 minutes)

### 8.1 Access WebUI

1. Open browser: `http://<MONITORING_EXTERNAL_IP>:9999`
2. Login: `admin` / `1423`

### 8.2 Add Test Subscriber

Click "Subscriber" → "+ Add" and enter:

```
IMSI: 999700000000001
K: 465B5CE8B199B49FAA5F0A2EE238A6BC
OPc: E8ED289DEBA952E4283B54E88E6183CA
AMF: 8000
APN/DNN: internet
SST: 1
```

Click "SAVE"

---

## ✅ STEP 9: Validation & Health Check (15 minutes)

### 9.1 Quick Validation Script

Run on your local machine:

```bash
# Set variables
ZONE="us-central1-a"

echo "=== Open5GS Validation ==="

# Check services on Control Plane
gcloud compute ssh open5gs-control --zone=$ZONE --command="
  echo 'Control Plane Services:'
  for svc in mmed hssd pcrfd sgwcd smfd nrfd amfd udmd udrd pcfd ausfd nssfd bsfd; do
    status=\$(systemctl is-active open5gs-\$svc 2>/dev/null)
    echo \"  open5gs-\$svc: \$status\"
  done
  echo ''
  echo 'Key Ports:'
  ss -tlnp | grep -E '36412|38412|7777' | head -5
"

# Check services on User Plane
gcloud compute ssh open5gs-userplane --zone=$ZONE --command="
  echo 'User Plane Services:'
  systemctl is-active open5gs-upfd open5gs-sgwud
  echo 'GTP-U Port:'
  ss -ulnp | grep 2152
"

# Get WebUI URL
WEBUI_IP=$(gcloud compute instances describe open5gs-monitoring --zone=$ZONE --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
echo ""
echo "WebUI: http://${WEBUI_IP}:9999 | Login: admin / 1423"
```

### 9.2 Expected Results

```
✅ All services show "active"
✅ Port 36412 (MME) listening
✅ Port 38412 (AMF) listening
✅ Port 2152 (GTP-U) listening
✅ WebUI accessible
```

---

---

## 🎯 What's Next?

**Phase 1 Complete!** ✅

You now have fully functional 4G EPC and 5G Core networks on GCP VMs.

---

## 📱 BONUS: Quick UERANSIM Test (30 minutes)

> **For academic demos:** This section lets you test UE connectivity without Phase 2.

### Install UERANSIM on RAN VM

```bash
gcloud compute ssh open5gs-ran --zone=$ZONE

# Install dependencies
sudo apt update
sudo apt install -y make gcc g++ libsctp-dev lksctp-tools iproute2 cmake

# Clone and build UERANSIM
cd ~
git clone https://github.com/aligungr/UERANSIM
cd UERANSIM
make
```

### Configure gNB (5G Base Station)

```bash
cat > config/open5gs-gnb.yaml << 'EOF'
mcc: '999'
mnc: '70'
nci: '0x000000010'
idLength: 32
tac: 1

linkIp: 10.10.0.100
ngapIp: 10.10.0.100
gtpIp: 10.10.0.100

amfConfigs:
  - address: 10.10.0.2
    port: 38412

slices:
  - sst: 1
EOF
```

### Configure UE (User Equipment)

```bash
cat > config/open5gs-ue.yaml << 'EOF'
supi: 'imsi-999700000000002'
mcc: '999'
mnc: '70'
key: '465B5CE8B199B49FAA5F0A2EE238A6BC'
op: 'E8ED289DEBA952E4283B54E88E6183CA'
opType: 'OPC'
amf: '8000'

gnbSearchList:
  - 10.10.0.100

sessions:
  - type: 'IPv4'
    apn: 'internet'
    slice:
      sst: 1

configured-nssai:
  - sst: 1
EOF
```

### Run Test

```bash
# Terminal 1: Start gNB
./build/nr-gnb -c config/open5gs-gnb.yaml

# Terminal 2 (new SSH session): Start UE
sudo ./build/nr-ue -c config/open5gs-ue.yaml

# Terminal 3: Test connectivity
ping -I uesimtun0 8.8.8.8
```

**Expected output:** `NG Setup procedure is successful` and ping replies!

---

**Proceed to (OPTIONAL):** [PHASE-2-VM-DevOps.md](PHASE-2-VM-DevOps.md) for automation, or [PHASE-3-VM-Monitoring.md](PHASE-3-VM-Monitoring.md) for monitoring.

---

**Time Spent:** 5-6 hours | **Status:** Core Networks Deployed & Validated
