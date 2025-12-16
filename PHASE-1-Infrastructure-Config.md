# PHASE 1: Infrastructure Provisioning & Network Deployment

**Duration:** 5-6 hours | **Complexity:** Intermediate | **Paradigm:** Network as Code (NaC)

---

## 📖 Phase Objectives

In this phase, you transition from **"clicking in GCP console"** to **"declaring infrastructure in code."** This is the foundation of DevOps. You will:

1. **Define infrastructure as code (Terraform)** - Two distinct VMs with purpose-built configurations
2. **Automate deployment (Ansible)** - Eliminate manual configuration errors through idempotent playbooks
3. **Provision the Core Network** - Install Open5GS control/user plane functions
4. **Provision the RAN Simulators** - Compile 4G (srsRAN) and 5G (UERANSIM) from source
5. **Register subscribers** - Database entries enabling authentication
6. **Validate connectivity** - Confirm 5G UE can attach and reach the internet

**Why this matters:** Every step is reproducible. You can tear down and rebuild the entire lab in 30 minutes using the same code. This is the definition of **Infrastructure as Code.**

---

## 🏗️ Architectural Decisions (Why Two VMs?)

### VM Strategy: Separation of Duties

**VM 1: The Core Node (`vm-core`)**

- **Role:** The "brain" - Control Plane and User Plane functions
- **Hosts:** Open5GS (AMF, SMF, UPF for 5G; MME, SGW for 4G), MongoDB, Prometheus, Grafana
- **Why separate?** Real-world networks have physically separate core and RAN. This separation allows you to measure backhaul latency.

**VM 2: The RAN Node (`vm-ran`)**

- **Role:** The "edge" - Radio Access Network simulators
- **Hosts:** srsRAN (4G eNB + UE) and UERANSIM (5G gNB + UE) compiled from source
- **Why separate?** Isolates heavy computation (radio simulation) from control logic. Allows independent scaling.

### Why `e2-medium` (2 vCPU, 4GB RAM)?

**Critical Constraint:** Compiling srsRAN (the 4G physical layer simulator) requires:

- ✓ At least 2GB RAM for the C++ compiler
- ✗ e2-micro (0.25GB) = Out-of-Memory crash
- ✗ e2-small (2GB) = Marginal, may fail
- ✓ e2-medium (4GB) = Safe minimum

OS: Ubuntu 22.04 LTS (stable kernel, modern SCTP support)

### Network Layout

```
GCP Project: telecom5g-prod2
│
├─ VPC: open5gs-vpc (10.10.0.0/16)
│  ├─ Control Subnet: 10.10.0.0/24
│  │  ├─ vm-core (10.10.0.2) - Control Plane + Observability
│  │  └─ vm-ran (10.10.0.100) - RAN Simulators
│  │
│  └─ UE Subnet: 10.45.0.0/16 (TUN device on vm-core)
│     └─ Simulated phone gets IP from this range
│
├─ Firewall: allow-5g-lab
│  └─ Allows ALL protocols (TCP, UDP, SCTP, GTP, etc.)
│     Why? Cellular networks use exotic protocols like SCTP
│
└─ External IPs: Only vm-core needs public IP for SSH
   └─ vm-ran accessed via IAP (Identity-Aware Proxy)
```

### 5G Core Network Functions Architecture

**Control Plane (SBI - Service-Based Interface):**

- **NRF** (Network Repository Function) - Service discovery registry
- **AMF** (Access Management Function) - UE attachment, mobility, security
- **SMF** (Session Management Function) - PDU session lifecycle, QoS enforcement
- **UDM** (Unified Data Management) - Subscriber profiles (encrypted)
- **UDR** (Unified Data Repository) - Policies and data rules
- **PCF** (Policy Control Function) - QoS policies and traffic rules
- **AUSF** (Authentication Server Function) - Challenge-response auth

**User Plane (N3/N6 interfaces):**

- **UPF** (User Plane Function) - Packet routing, firewall, QoS marking

### Protocols Used (Why the Firewall Is Open)

Your firewall allows `0.0.0.0/0` to `0-65535` because cellular networks use specialized protocols:

| Layer          | 4G (LTE)              | 5G (NR)               | Port        | Protocol                  |
| -------------- | --------------------- | --------------------- | ----------- | ------------------------- |
| **Access**     | S1-MME (eNB↔MME)      | NGAP (gNB↔AMF)        | 36412/38412 | **SCTP** _(not TCP/UDP!)_ |
| **Session**    | GTP-C (SGW control)   | N4 (SMF↔UPF)          | 2123/8805   | UDP + PFCP                |
| **Data Plane** | GTP-U (SGW user data) | GTP-U (UPF user data) | 2152        | UDP                       |
| **Discovery**  | HTTP (legacy)         | HTTP/2 (SBI)          | 7777-7783   | TCP/HTTP                  |

**SCTP (Stream Control Transmission Protocol):**

- Layer 4 protocol (like TCP/UDP, but message-oriented)
- Default firewalls often block it
- Required for 5G NGAP signaling
- Solution: Your Terraform firewall rule allows IP Protocol 132 (SCTP)

---

## 📋 Prerequisites

### GCP Requirements

- ✅ GCP account with billing enabled
- ✅ Google Cloud SDK installed locally
- ✅ Project created in GCP console

### Local Tools

```bash
# Install Google Cloud SDK
# https://cloud.google.com/sdk/docs/install

# Verify installation
gcloud --version
terraform --version
ansible --version
```

---

## 🔧 Step 1: GCP Project Setup (15 minutes)

### 1.1 Authenticate with GCP

```bash
gcloud auth login
gcloud auth application-default login
```

### 1.2 Set Project Configuration

```bash
export PROJECT_ID="telecom5g-prod2"
export REGION="us-central1"
export ZONE="us-central1-a"

gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Verify configuration
gcloud config list
```

### 1.3 Enable Required APIs

```bash
gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable iap.googleapis.com
```

### 1.4 Create Service Account (for Terraform)

```bash
gcloud iam service-accounts create terraform-sa \
  --display-name="Terraform Service Account"

# Grant necessary permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/compute.admin"

# Create key
gcloud iam service-accounts keys create ~/terraform-key.json \
  --iam-account=terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com

export GOOGLE_APPLICATION_CREDENTIALS=~/terraform-key.json
```

---

## 🔨 Step 2: Infrastructure Provisioning with Terraform (30 minutes)

### 2.1 Initialize Terraform

```bash
cd terraform
terraform init
```

### 2.2 Review Terraform Plan

```bash
terraform plan
```

This should show:

- 2 VM instances (vm-core, vm-ran)
- 1 VPC network
- 1 firewall rule set
- 1 external IP address

### 2.3 Apply Terraform Configuration

```bash
terraform apply -auto-approve
```

### 2.4 Retrieve Infrastructure Details

```bash
terraform output
```

Save these outputs for later use:

- `vm_core_internal_ip` - Control Plane VM internal IP
- `vm_ran_internal_ip` - RAN VM internal IP
- `vm_core_external_ip` - Control Plane external IP (if applicable)

---

## 🐧 Step 3: System Preparation on VMs (20 minutes)

### 3.1 SSH into vm-core

```bash
gcloud compute ssh vm-core --zone=$ZONE
```

### 3.2 Update System

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl wget git build-essential
```

### 3.3 Disable Swap (Required for Open5GS)

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

### 3.4 Enable IP Forwarding

```bash
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.all.forwarding=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 3.5 Create TUN/TAP Device

```bash
sudo ip tuntap add name ogstun mode tun
sudo ip addr add 10.45.0.1/16 dev ogstun
sudo ip link set dev ogstun up
```

### 3.6 Repeat for vm-ran

```bash
gcloud compute ssh vm-ran --zone=$ZONE
# Repeat steps 3.2-3.4 (skip 3.5 as no TUN needed on RAN)
```

---

## 📦 Step 4: Open5GS Installation (60 minutes)

### 4.1 Add Open5GS Repository

On **vm-core**:

```bash
curl -fsSL https://open5gs.org/open5gs/assets/open5gs-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/open5gs.gpg
echo "deb [signed-by=/usr/share/keyrings/open5gs.gpg] https://ppa.launchpadcontent.com/acetcom/open5gs/ubuntu jammy main" | \
  sudo tee /etc/apt/sources.list.d/open5gs.list

sudo apt update
```

### 4.2 Install Open5GS

```bash
sudo apt install -y open5gs open5gs-webui
```

### 4.3 Install MongoDB

```bash
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb.gpg
echo "deb [signed-by=/usr/share/keyrings/mongodb.gpg] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list

sudo apt update
sudo apt install -y mongodb-org-mongosh mongodb-mongosh-shared-openssl3
sudo systemctl enable mongod
sudo systemctl start mongod
```

### 4.4 Verify Installation

```bash
# Check Open5GS services
sudo systemctl status open5gs-nrfd
sudo systemctl status open5gs-amfd
sudo systemctl status open5gs-smfd

# Check MongoDB
mongosh --eval "db.adminCommand('ping')"
```

---

## ⚙️ Step 5: Open5GS Configuration (90 minutes)

### The IP Binding Requirement (Critical Step)

By default, Open5GS listens on `localhost` (127.0.0.1). This means:

- ✗ vm-ran cannot reach the Core network
- ✗ NGAP signaling (port 38412) is unreachable
- ✗ PFCP (port 8805) is unreachable

**Solution:** Update every config file (`amf.yaml`, `smf.yaml`, `upf.yaml`, etc.) to bind to the **VM's private IP address** (10.10.0.2):

```yaml
amf:
  sbi:
    server:
      - address: 10.10.0.2 # ← Changed from 127.0.0.1
        port: 7778
```

This single change enables cross-VM communication and is the difference between "network exists on localhost only" vs. "network exists across the cloud."

### The NAT Masquerading Requirement (Internet Access)

When your simulated 5G phone wants to ping `google.com`, here's what happens:

1. **Phone generates:** `PING google.com` from inside uesimtun0 (10.45.0.2)
2. **UPF routes:** Packet to the Core VM's default gateway
3. **Core VM must masquerade:** Use iptables NAT to rewrite the source IP
4. **Google sees:** Request from Core VM public IP (not from the fake 10.45.0.2)
5. **Reply comes back** and is translated again

**Configuration:**

```bash
sudo sysctl -w net.ipv4.ip_forward=1  # Enable kernel forwarding
sudo iptables -t nat -A POSTROUTING -s 10.45.0.0/16 -j MASQUERADE
```

Without this, the simulated phone is "air-gapped" and cannot reach the internet.

---

### 5.1 Configure NRF

Edit `/etc/open5gs/nrf.yaml`:

```yaml
nrf:
  sbi:
    server:
      - address: 10.10.0.2
        port: 7777
        http: 2
```

### 5.2 Configure AMF

Edit `/etc/open5gs/amf.yaml`:

```yaml
amf:
  sbi:
    server:
      - address: 10.10.0.2
        port: 7778
        http: 2
  ngap:
    server:
      - address: 10.10.0.2
        port: 38412
        protocol: sctp
  guami:
    - plmn_id:
        mcc: "999"
        mnc: "70"
      amf_id:
        region: "00"
        set: "001"
  tai:
    - plmn_id:
        mcc: "999"
        mnc: "70"
      tac: 1
  plmn_support:
    - plmn_id:
        mcc: "999"
        mnc: "70"
      s_nssai:
        - sst: 0
nrf:
  uri: http://10.10.0.2:7777
```

### 5.3 Configure SMF

Edit `/etc/open5gs/smf.yaml`:

```yaml
smf:
  sbi:
    server:
      - address: 10.10.0.2
        port: 7776
        http: 2
  pfcp:
    server:
      - address: 10.10.0.2
        port: 8805
  gtpc:
    server:
      - address: 10.10.0.2
        port: 2123
  subnet:
    - addr: 10.45.0.0/16
      dnn: internet
  dns:
    - 8.8.8.8
    - 8.8.4.4
nrf:
  uri: http://10.10.0.2:7777
upf:
  pfcp:
    - address: 10.10.0.2
```

### 5.4 Configure UPF

Edit `/etc/open5gs/upf.yaml`:

```yaml
upf:
  pfcp:
    server:
      - address: 10.10.0.2
        port: 8805
  gtpu:
    server:
      - address: 10.10.0.2
        port: 2152
  subnet:
    - addr: 10.45.0.0/16
      dnn: internet
      dev: ogstun
```

### 5.5 Configure UDM, UDR, PCF, AUSF

Update each file in `/etc/open5gs/`:

```yaml
# Common pattern for all
nrf:
  uri: http://10.10.0.2:7777

# UDM
udm:
  sbi:
    server:
      - address: 10.10.0.2
        port: 7780
        http: 2

# UDR
udr:
  sbi:
    server:
      - address: 10.10.0.2
        port: 7783
        http: 2

# PCF
pcf:
  sbi:
    server:
      - address: 10.10.0.2
        port: 7781
        http: 2

# AUSF
ausf:
  sbi:
    server:
      - address: 10.10.0.2
        port: 7779
        http: 2
```

### 5.6 Restart Services

```bash
sudo systemctl restart open5gs-nrfd
sudo systemctl restart open5gs-amfd
sudo systemctl restart open5gs-smfd
sudo systemctl restart open5gs-udmd
sudo systemctl restart open5gs-udrd
sudo systemctl restart open5gs-pcfd
sudo systemctl restart open5gs-ausfd
sudo systemctl restart open5gs-upfd
```

### 5.7 Verify Services

```bash
sudo systemctl status open5gs-*
```

All should show **active (running)**.

---

## 🗄️ Step 6: Subscriber Provisioning (15 minutes)

### 6.1 Add Subscriber via WebUI

1. Open browser: `http://<vm-core-public-ip>:3000`
2. Login: admin / 1423
3. Click "Subscribers"
4. Click "+" button
5. Fill in:
   - **Name:** test-user
   - **IMSI:** 999700000000001
   - **Secret (K):** 465B5CE8B199B49FAA5F0A2EE238A6BC
   - **OPc:** E8ED289DEBA952E4283B54E88E6183CA
   - **Slice:** SST=0, DNN=internet

### 6.2 Verify Subscriber in MongoDB

```bash
mongosh
use open5gs
db.subscribers.findOne()
```

---

## 🛰️ Step 7: UERANSIM Setup on vm-ran (45 minutes)

### 7.1 Install Dependencies

On **vm-ran**:

```bash
sudo apt install -y git gcc g++ cmake make libsctp-dev libgtest-dev
sudo apt install -y libssl-dev libboost-all-dev libfmt-dev
```

### 7.2 Clone UERANSIM

```bash
cd ~
git clone https://github.com/aligungr/UERANSIM.git
cd UERANSIM
git checkout v3.2.6
```

### 7.3 Build UERANSIM

```bash
cd build
cmake ..
make -j$(nproc)
cd ..
```

Expected output: `nr-gnb` and `nr-ue` binaries in `build/` directory

### 7.4 Configure gNB

Create `config/open5gs-gnb.yaml`:

```yaml
mcc: "999"
mnc: "70"
nci: "0x000000010"
tac: 1
linkIp: 10.10.0.100
ngapIp: 10.10.0.100
gtpIp: 10.10.0.100
amfConfigs:
  - address: 10.10.0.2
    port: 38412
slices:
  - sst: 0
ignoreStreamIds: true
```

### 7.5 Configure UE

Create `config/open5gs-ue.yaml`:

```yaml
supi: "imsi-999700000000001"
mcc: "999"
mnc: "70"
key: "465B5CE8B199B49FAA5F0A2EE238A6BC"
op: "E8ED289DEBA952E4283B54E88E6183CA"
opType: "OPC"
amf: "8000"
gnbSearchList: [10.10.0.100]
sessions:
  - type: "IPv4"
    apn: "internet"
    slice: { sst: 0 }
configured-nssai: [{ sst: 0 }]
default-nssai: [{ sst: 0 }]
integrity: { IA1: false, IA2: true, IA3: false }
ciphering: { EA1: false, EA2: true, EA3: false }
integrityMaxRate: { uplink: "full", downlink: "full" }
```

---

## ✅ Step 8: Validation & Testing (30 minutes)

### 8.1 Test gNB Connection

On **vm-ran**, in Terminal 1:

```bash
cd ~/UERANSIM
timeout 15 ./build/nr-gnb -c config/open5gs-gnb.yaml
```

**Expected Output:**

```
[sctp] [info] SCTP connection established
[ngap] [info] NG Setup procedure is successful
```

### 8.2 Test UE Registration

On **vm-ran**, in Terminal 2:

```bash
cd ~/UERANSIM
sudo ./build/nr-ue -c config/open5gs-ue.yaml
```

**Expected Output:**

```
[nas] [info] UE NAS registration procedure
[mm] [info] MM-REGISTERED/NORMAL-SERVICE
```

### 8.3 Test Connectivity

On **vm-ran**, in Terminal 3:

```bash
sudo ip addr show uesimtun0
sudo ping -I uesimtun0 -c 5 8.8.8.8
```

**Expected Output:**

```
5 packets transmitted, 5 received, 0% packet loss
```

---

## 🎯 Success Criteria

Phase 1 is complete when:

- ✅ VMs provisioned and accessible via SSH
- ✅ MongoDB running and accessible
- ✅ All Open5GS services active (`systemctl status`)
- ✅ Subscriber registered in MongoDB
- ✅ gNB shows "NG Setup procedure is successful"
- ✅ UE shows "MM-REGISTERED/NORMAL-SERVICE"
- ✅ Ping through uesimtun0 successful

---

## 🐛 Troubleshooting

### AMF Won't Start

```bash
sudo systemctl status open5gs-amfd
sudo journalctl -u open5gs-amfd -n 50
```

**Common Issue:** Missing PLMN in configuration  
**Solution:** Verify MCC/MNC in amf.yaml matches all other configs (999/70)

### UE Can't Find Cell

```bash
# Check gNB logs for:
# [sctp] connection failed
# Verify: gNB IP is correct and firewall allows port 38412
```

**Common Issue:** Firewall blocking NGAP port (38412)  
**Solution:** Check GCP firewall rules allow traffic between 10.10.0.0/16

### MongoDB Connection Failed

```bash
mongosh --host 10.10.0.2
```

**Common Issue:** MongoDB not running  
**Solution:** `sudo systemctl restart mongod`

---

## 📝 Next Steps

Once Phase 1 validation is complete:

1. Proceed to **[PHASE-2-Testing-Benchmarking.md](PHASE-2-Testing-Benchmarking.md)**
2. Set up performance benchmarking
3. Configure Prometheus & Grafana monitoring
4. Run comparative analysis (4G vs 5G)

---

**Status:** Phase 1 Complete ✅ | **Duration:** 5-6 hours | **Complexity:** Intermediate
