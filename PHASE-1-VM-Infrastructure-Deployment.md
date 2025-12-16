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

## 🐧 Step 3: Configure SSH & Ansible (10 minutes)

### 3.1 Generate SSH Key (If Needed)

```bash
# Generate ED25519 SSH key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
```

### 3.2 Disable OS Login on VMs

```bash
gcloud compute instances add-metadata vm-core \
  --zone=us-central1-a \
  --metadata enable-oslogin=FALSE

gcloud compute instances add-metadata vm-ran \
  --zone=us-central1-a \
  --metadata enable-oslogin=FALSE

sleep 10
```

### 3.3 Add SSH Keys to VM Metadata

```bash
# Add SSH key to vm-core
gcloud compute instances add-metadata vm-core \
  --zone=us-central1-a \
  --metadata-from-file ssh-keys=<(echo "ubuntu:$(cat ~/.ssh/id_ed25519.pub)")

# Add SSH key to vm-ran
gcloud compute instances add-metadata vm-ran \
  --zone=us-central1-a \
  --metadata-from-file ssh-keys=<(echo "ubuntu:$(cat ~/.ssh/id_ed25519.pub)")

sleep 30
```

### 3.4 Verify Ansible Connection

```bash
cd ansible

# Test SSH connectivity
ansible all -i inventory/hosts.ini -m ping
```

Expected output: Both hosts respond with `pong`

---

## 📦 Step 4: Deploy Open5GS with Ansible (5-10 minutes)

### 4.1 Run Open5GS Deployment Playbook

```bash
cd ansible

# Deploy Open5GS core network
ansible-playbook -i inventory/hosts.ini playbooks/deploy-core.yml -vv
```

**What the playbook does:**

- ✅ Fixes DNS resolution (8.8.8.8, 1.1.1.1)
- ✅ Updates system packages (with 3 retries)
- ✅ Installs MongoDB and creates database
- ✅ Adds Open5GS repository and installs all services
- ✅ Enables IP forwarding
- ✅ Creates TUN/TAP device (ogstun)
- ✅ Configures NAT masquerading for UE subnet
- ✅ Starts all Open5GS services (NRF, AMF, SMF, UPF, UDM, UDR, PCF, AUSF)
- ✅ Starts MongoDB and Prometheus

### 4.2 Verify Open5GS Services

After the playbook completes successfully, SSH to vm-core and verify:

```bash
gcloud compute ssh vm-core --zone=us-central1-a

# Check all services are running
sudo systemctl status open5gs-*
sudo systemctl status mongod

# View recent logs
journalctl -u open5gs-amfd -n 50
```

All services should show **active (running)**.

---

## 🛰️ Step 5: Deploy UERANSIM with Ansible (10-15 minutes)

### 5.1 Run UERANSIM Deployment Playbook

```bash
cd ansible

# Deploy UERANSIM RAN simulator
ansible-playbook -i inventory/hosts.ini playbooks/deploy-ueransim.yml -vv
```

**What the playbook does:**

- ✅ Fixes DNS resolution on vm-ran
- ✅ Installs build dependencies (cmake, gcc, g++, libsctp-dev, etc.)
- ✅ Clones UERANSIM v3.2.6 from GitHub
- ✅ Compiles UERANSIM with parallel make (-j$(nproc))
- ✅ Creates gNB configuration (`open5gs-gnb.yaml`) with PLMN 999/70
- ✅ Creates UE configuration (`open5gs-ue.yaml`) with security keys
- ✅ Sets proper file ownership to ubuntu user

**Build time:** ~10-15 minutes (depending on VM resources)

### 5.2 Verify UERANSIM Installation

After the playbook completes:

```bash
gcloud compute ssh vm-ran --zone=us-central1-a

# Check UERANSIM was built
ls -la ~/UERANSIM/
ls -la ~/UERANSIM/build/

# Verify configuration files
cat ~/UERANSIM/config/open5gs-gnb.yaml
cat ~/UERANSIM/config/open5gs-ue.yaml
```

Expected: Both `nr-gnb` and `nr-ue` binaries exist in `~/UERANSIM/build/`

---

## 🗄️ Step 6: Subscriber Provisioning (15 minutes)

### 6.1 Add Subscriber via WebUI

Open5GS comes with a WebUI for subscriber management. Access it via:

1. Get the public IP:

   ```bash
   cd terraform
   terraform output vm_core_public_ip
   ```

2. Open browser: `http://<PUBLIC_IP>:3000`
3. Login: **admin** / **1423**
4. Click "**Subscribers**"
5. Click "**+**" button to add new subscriber
6. Fill in:
   - **Name:** test-user
   - **IMSI:** 999700000000001
   - **Secret (K):** 465B5CE8B199B49FAA5F0A2EE238A6BC
   - **OPc:** E8ED289DEBA952E4283B54E88E6183CA
   - **Slice:** SST=0, DNN=internet
7. Click "**Save**"

### 6.2 Verify Subscriber in MongoDB

```bash
# SSH to vm-core
gcloud compute ssh vm-core --zone=us-central1-a

# Check subscriber was created
mongosh
use open5gs
db.subscribers.findOne()
```

Should display the subscriber record with IMSI 999700000000001.

---

## ✅ Step 7: Validation & Testing (30 minutes)

### 7.1 Test gNB Connection

On **vm-ran**, start the gNB:

```bash
gcloud compute ssh vm-ran --zone=us-central1-a

cd ~/UERANSIM
timeout 15 ./build/nr-gnb -c config/open5gs-gnb.yaml
```

**Expected Output:**

```
[sctp] [info] SCTP connection established
[ngap] [info] NG Setup procedure is successful
```

This shows the gNB successfully connected to the AMF on vm-core via the network configured by Ansible.

### 7.2 Test UE Registration

On **vm-ran**, in a second terminal:

```bash
gcloud compute ssh vm-ran --zone=us-central1-a

cd ~/UERANSIM
sudo ./build/nr-ue -c config/open5gs-ue.yaml
```

**Expected Output:**

```
[nas] [info] UE NAS registration procedure
[mm] [info] MM-REGISTERED/NORMAL-SERVICE
[ps] [info] Session established
```

This shows the UE (simulated phone) successfully registered with the 5G network.

### 7.3 Test Connectivity

On **vm-ran**, in a third terminal:

```bash
gcloud compute ssh vm-ran --zone=us-central1-a

# Check the UE got an IP address
sudo ip addr show uesimtun0

# Test internet connectivity
sudo ping -I uesimtun0 -c 5 8.8.8.8
```

**Expected Output:**

```
5 packets transmitted, 5 received, 0% packet loss
```

This demonstrates the UE can reach the internet through the UPF (configured by Ansible).

---

## 🎯 Success Criteria

Phase 1 is complete when:

- ✅ Terraform provisioned infrastructure (2 VMs, VPC, firewall)
- ✅ SSH keys configured and Ansible connectivity verified
- ✅ Ansible playbook for Open5GS ran successfully
- ✅ All Open5GS services running (`systemctl status`)
- ✅ MongoDB accessible and subscriber provisioned
- ✅ Ansible playbook for UERANSIM ran successfully
- ✅ gNB shows "NG Setup procedure is successful"
- ✅ UE shows "MM-REGISTERED/NORMAL-SERVICE"
- ✅ Ping through uesimtun0 successful

---

## 📋 Summary of Ansible Automation

| Step            | Manual Process (Old)                  | Ansible Automation (New)  | Time Saved |
| --------------- | ------------------------------------- | ------------------------- | ---------- |
| System Prep     | SSH, edit files, run commands         | Playbook handles all      | ~20 min    |
| Open5GS Install | Download, install, configure manually | Playbook + retries        | ~60 min    |
| MongoDB Setup   | Manual install & service start        | Playbook automates        | ~15 min    |
| UERANSIM Build  | SSH, clone, compile, configure        | Playbook + parallel build | ~45 min    |
| **TOTAL**       | ~140 minutes manual work              | ~15 minutes playbook      | ~125 min   |

The Ansible playbooks ensure:

- ✅ Consistent configuration across runs
- ✅ Idempotent operations (safe to re-run)
- ✅ DNS and retry logic built-in
- ✅ All services start automatically
- ✅ Configuration templates pre-filled with correct PLMN/IMSI

---

## 🐛 Troubleshooting

### Ansible Playbook Fails to Connect

**Issue:** Playbook says "unreachable" for hosts

**Solution:**

```bash
# Verify SSH key is added
gcloud compute instances describe vm-core --zone=us-central1-a | grep ssh-keys

# Test SSH manually
ssh -i ~/.ssh/id_ed25519 ubuntu@<PUBLIC_IP> "whoami"

# Update inventory with correct public IP
terraform output vm_core_public_ip
```

### Open5GS Services Don't Start

**Issue:** Playbook completes but services are not running

**Solution:**

```bash
# SSH to vm-core and check
gcloud compute ssh vm-core --zone=us-central1-a

# View service logs
sudo journalctl -u open5gs-amfd -n 50

# Check DNS resolution
cat /etc/resolv.conf
```

### UERANSIM Build Fails

**Issue:** Playbook fails at compilation step

**Solution:**

```bash
# Check disk space on vm-ran
gcloud compute ssh vm-ran --zone=us-central1-a
df -h
free -m

# If low on space, clean and rebuild
cd ~/UERANSIM
make clean
make -j$(nproc)
```

### gNB Can't Connect to AMF

**Issue:** gNB shows "connection failed"

**Solution:**

```bash
# Verify AMF is running on core
gcloud compute ssh vm-core --zone=us-central1-a
sudo systemctl status open5gs-amfd

# Test connectivity from RAN to Core
gcloud compute ssh vm-ran --zone=us-central1-a
ping 10.10.0.2
nc -zv 10.10.0.2 38412
```

---

## 📝 Next Steps

Once Phase 1 validation is complete:

1. Proceed to **[PHASE-2-Testing-Benchmarking.md](PHASE-2-Testing-Benchmarking.md)**
2. Run performance tests and benchmarks
3. Compare 4G vs 5G performance
4. Configure monitoring and observability

---

**Status:** Phase 1 Complete ✅ | **Method:** Infrastructure as Code + Ansible Automation | **Deployment Time:** ~30 minutes

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
