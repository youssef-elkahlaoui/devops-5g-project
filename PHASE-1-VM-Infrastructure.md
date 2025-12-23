
# PHASE 1: Infrastructure & Core Network Deployment (3-VM Architecture)

**⏱️ Duration: 60-90 Minutes | 🎯 Goal: Separate 4G, 5G, and Monitoring Infrastructure on GCP**

---

## 📋 Phase 1 Overview

In this phase, you will deploy a complete 3-VM architecture with full isolation:

1. **Network Infrastructure** - VPC, subnets, firewall rules, Cloud NAT
2. **VM1 (10.10.0.10)** - Dedicated 4G Core + srsRAN + MongoDB
3. **VM2 (10.10.0.20)** - Dedicated 5G Core + UERANSIM + MongoDB
4. **VM3 (10.10.0.30)** - Centralized Monitoring (Prometheus + Grafana)
5. **Verification** - Test each VM independently

### Architecture Overview

```
                        GCP VPC: open5gs-vpc
                       Subnet: 10.10.0.0/24

    VM1 (4G Core)          VM2 (5G Core)         VM3 (Monitoring)
    10.10.0.10             10.10.0.20            10.10.0.30
    ─────────────          ─────────────         ─────────────
    Open5GS EPC            Open5GS 5GC           Prometheus
    MME, SGW, PGW          AMF, SMF, UPF         (scrapes VM1 & VM2)
    HSS, PCRF              NRF, UDM, PCF
    srsRAN eNB/UE          UERANSIM gNB/UE       Grafana
    MongoDB 8.0            MongoDB 8.0           (dashboards)
    WebUI:9999             WebUI:9999
    Metrics:9090           Metrics:9090          Port:3000
    Node Exp:9100          Node Exp:9100         Port:9090
```

**Result:** Three isolated VMs with centralized monitoring for 4G vs 5G comparison

---

## ✅ Prerequisites

```bash
# Required tools
gcloud --version    # Google Cloud SDK 450.0.0+
terraform --version # 1.5.0+
ansible --version   # 2.15.0+
git --version       # Any recent version

# Authentication
gcloud auth login
gcloud auth application-default login
```

---

## 🌐 STEP 1: Deploy Network Infrastructure (10 minutes)

### 1.1 Navigate to Network Terraform

```bash
cd c:\Users\jozef\OneDrive\Desktop\devops-5g-project\terraform-network
```

### 1.2 Review Configuration

The network Terraform creates:

- **VPC**: open5gs-vpc (custom mode)
- **Subnet**: control-subnet (10.10.0.0/24)
- **Firewall Rules**: SSH, SCTP, GTP-U/C, HTTP/2, Diameter, WebUI, Monitoring, Internal
- **Cloud NAT**: For internet access from VMs

### 1.3 Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy network infrastructure
terraform apply -auto-approve

# Expected output:
# - VPC created: open5gs-vpc
# - Subnet created: control-subnet (10.10.0.0/24)
# - 11 firewall rules created
# - Cloud Router and NAT created
```

### 1.4 Verify Network

```bash
# List VPC
gcloud compute networks list | grep open5gs-vpc

# List firewall rules
gcloud compute firewall-rules list --filter="network:open5gs-vpc"

# Check Cloud NAT
gcloud compute routers nats list --router=open5gs-router --region=us-central1
```

**✅ Checkpoint:** Network infrastructure deployed successfully

---

## 💻 STEP 2: Deploy VM1 (4G Core Network) (20 minutes)

### 2.1 Deploy VM1 Infrastructure

```bash
cd ../terraform-vm1-4g

# Initialize Terraform
terraform init

# Review VM1 configuration
terraform plan

# Deploy VM1
terraform apply -auto-approve

# Get VM1 public IP
export VM1_IP=$(terraform output -raw vm1_public_ip)
echo "VM1 Public IP: $VM1_IP"
```

### 2.2 Test VM1 Connectivity

```bash
# Test SSH connectivity
ssh ayoubgory_gmail_com@$VM1_IP "echo 'VM1 SSH successful'"

# Verify OS Login user
ssh ayoubgory_gmail_com@$VM1_IP "whoami"
# Expected: ayoubgory_gmail_com
```

### 2.3 Deploy 4G Software Stack

```bash
cd ..\ansible-vm1-4g

# Update inventory with VM1 public IP
notepad inventory\hosts.ini
# Edit: ansible_host=<VM1_PUBLIC_IP>

# Deploy Open5GS EPC + srsRAN + MongoDB
ansible-playbook -i inventory/hosts.ini playbooks/deploy-4g-core.yml -vv

# Expected duration: 15-20 minutes
# Expected output:
# - MongoDB 8.0 installed
# - Open5GS EPC packages installed (mme, sgwc, sgwu, pgw, hss, pcrf)
# - All services configured with IP 10.10.0.10
# - 4G subscriber added (IMSI: 001010000000001)
# - srsRAN built from source
# - Node Exporter installed
```

### 2.4 Verify VM1 Deployment

```bash
# SSH to VM1
ssh ayoubgory_gmail_com@$VM1_IP

# Check MongoDB
mongosh --eval "db.adminCommand('ping')"

# Check Open5GS services
sudo systemctl status open5gs-mmed
sudo systemctl status open5gs-sgwcd
sudo systemctl status open5gs-pgwd

# Check subscriber in database
mongosh open5gs --eval "db.subscribers.find().pretty()"

# Check srsRAN installation
ls -la /home/ayoubgory_gmail_com/srsRAN/build/srsenb/src/srsenb

# Check Node Exporter
curl http://localhost:9100/metrics | head -n 20

# Exit VM1
exit
```

### 2.5 Test VM1 User Connectivity

```bash
# Quick verification that 4G user is configured
ssh ayoubgory_gmail_com@$VM1_IP "mongosh open5gs --eval \"db.subscribers.findOne({imsi: '001010000000001'})\" | grep -o '\"imsi\" : \"001010000000001\"'"

# Expected: "imsi" : "001010000000001"

# Note: Full connectivity testing requires starting srsRAN simulation (see Phase 2)
# Example commands for Phase 2:
# sudo ./start-enb.sh  # Start 4G base station
# sudo ./start-ue.sh   # Start 4G user equipment
# sudo ip netns exec ue1 ping -c 10 8.8.8.8  # Test connectivity
```

**✅ Checkpoint:** VM1 (4G Core) deployed, verified, and user configured

---

## 💻 STEP 3: Deploy VM2 (5G Core Network) (20 minutes)

### 3.1 Deploy VM2 Infrastructure

```bash
cd ../terraform-vm2-5g

# Initialize Terraform
terraform init

# Review VM2 configuration
terraform plan

# Deploy VM2
terraform apply -auto-approve

# Get VM2 public IP
export VM2_IP=$(terraform output -raw vm2_public_ip)
echo "VM2 Public IP: $VM2_IP"
```

### 3.2 Test VM2 Connectivity

```bash
# Test SSH connectivity
ssh ayoubgory_gmail_com@$VM2_IP "echo 'VM2 SSH successful'"

# Verify OS Login user
ssh ayoubgory_gmail_com@$VM2_IP "whoami"
# Expected: ayoubgory_gmail_com
```

### 3.3 Deploy 5G Software Stack

```bash
cd ..\ansible-vm2-5g

# Update inventory with VM2 public IP
notepad inventory\hosts.ini
# Edit: ansible_host=<VM2_PUBLIC_IP>

# Deploy Open5GS 5GC + UERANSIM + MongoDB
ansible-playbook -i inventory/hosts.ini playbooks/deploy-5g-core.yml -vv

# Expected duration: 15-20 minutes
# Expected output:
# - MongoDB 8.0 installed
# - Open5GS 5GC packages installed (nrf, amf, smf, upf, udm, udr, pcf, ausf, nssf)
# - All services configured with IP 10.10.0.20
# - 5G subscriber added (IMSI: 999700000000001)
# - UERANSIM built from source
# - Node Exporter installed
```

### 3.4 Verify VM2 Deployment

```bash
# SSH to VM2
ssh ayoubgory_gmail_com@$VM2_IP

# Check MongoDB
mongosh --eval "db.adminCommand('ping')"

# Check Open5GS services
sudo systemctl status open5gs-nrfd
sudo systemctl status open5gs-amfd
sudo systemctl status open5gs-smfd

# Check subscriber in database
mongosh open5gs --eval "db.subscribers.find().pretty()"

# Check UERANSIM installation
ls -la /home/ayoubgory_gmail_com/UERANSIM/build/nr-gnb

# Check Node Exporter
curl http://localhost:9100/metrics | head -n 20

# Test NRF SBI
curl http://localhost:7777/nnrf-nfm/v1/nf-instances | jq .

# Exit VM2
exit
```

### 3.5 Test VM2 User Connectivity

```bash
# Quick verification that 5G user is configured
ssh ayoubgory_gmail_com@$VM2_IP "mongosh open5gs --eval \"db.subscribers.findOne({imsi: '999700000000001'})\" | grep -o '\"imsi\" : \"999700000000001\"'"

# Expected: "imsi" : "999700000000001"

# Note: Full connectivity testing requires starting UERANSIM simulation (see Phase 2)
# Example commands for Phase 2:
# sudo ./build/nr-gnb -c config/open5gs-gnb.yaml  # Start 5G base station
# sudo ./build/nr-ue -c config/open5gs-ue.yaml     # Start 5G user equipment
# sudo ping -I uesimtun0 -c 10 8.8.8.8            # Test connectivity
```

**✅ Checkpoint:** VM2 (5G Core) deployed, verified, and user configured

---

## 📊 STEP 4: Deploy VM3 (Monitoring Infrastructure) (15 minutes)

### 4.1 Deploy VM3 Infrastructure

```bash
cd ..\terraform-vm3-monitoring

# Initialize Terraform
terraform init

# Review VM3 configuration
terraform plan

# Deploy VM3
terraform apply -auto-approve

# Get VM3 public IP
terraform output vm3_public_ip
```

### 4.2 Configure SSH Access

```bash
# Get VM3 IP
$VM3_IP = (terraform output -raw vm3_public_ip)
Write-Host "VM3 Public IP: $VM3_IP"

# Test SSH connection
ssh ayoubgory_gmail_com@$VM3_IP "echo 'VM3 SSH successful'"
```

### 4.3 Deploy Monitoring Stack

```bash
cd ..\ansible-vm3-monitoring

# Update inventory with VM3 public IP
notepad inventory\hosts.ini
# Edit: ansible_host=<VM3_PUBLIC_IP>

# Deploy Prometheus + Grafana
ansible-playbook -i inventory/hosts.ini playbooks/deploy-monitoring.yml -vv

# Expected duration: 10-15 minutes
# Expected output:
# - Prometheus installed with scraping config for all 6 targets
# - Grafana installed with Prometheus data source
# - 4G vs 5G comparison dashboard created
# - Node Exporter installed
```

### 4.4 Verify VM3 Deployment

```bash
# SSH to VM3
ssh ayoubgory_gmail_com@$VM3_IP

# Check Prometheus service
sudo systemctl status prometheus

# Check Grafana service
sudo systemctl status grafana-server

# Check Prometheus targets (should show 6 targets)
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Expected targets:
# 1. prometheus (localhost:9090)
# 2. open5gs-4g-core (10.10.0.10:9090)
# 3. node-vm1-4g (10.10.0.10:9100)
# 4. open5gs-5g-core (10.10.0.20:9090)
# 5. node-vm2-5g (10.10.0.20:9100)
# 6. node-vm3-monitoring (localhost:9100)

# Test connectivity to VM1
ping -c 3 10.10.0.10

# Test connectivity to VM2
ping -c 3 10.10.0.20

# Test scraping VM1 metrics
curl http://10.10.0.10:9100/metrics | head -n 10

# Test scraping VM2 metrics
curl http://10.10.0.20:9100/metrics | head -n 10

# Exit VM3
exit
```

### 4.5 Access Monitoring Dashboards

```bash
# Open Grafana in browser
echo "Grafana: http://$VM3_IP:3000"
echo "Username: admin"
echo "Password: admin"

# Open Prometheus in browser
echo "Prometheus: http://$VM3_IP:9090"
```

**✅ Checkpoint:** VM3 (Monitoring) deployed and scraping both VMs

---

## 🧪 STEP 5: Run Verification Tests (15 minutes)

### 5.1 Test VM1 (4G Core)

```bash
# Copy test script to VM1
scp scripts/test-vm1-4g.sh ayoubgory_gmail_com@$VM1_IP:/home/ayoubgory_gmail_com/

# Run test script
ssh ayoubgory_gmail_com@$VM1_IP "bash /home/ayoubgory_gmail_com/test-vm1-4g.sh"

# Expected results:
# ✅ MongoDB ping successful
# ✅ 4G subscriber found (IMSI: 001010000000001)
# ✅ open5gs-mmed running
# ✅ open5gs-sgwcd running
# ✅ open5gs-sgwud running
# ✅ open5gs-pgwd running
# ✅ open5gs-hssd running
# ✅ open5gs-pcrfd running
# ✅ WebUI accessible on port 9999
# ✅ MME port 36412 (SCTP) open
# ✅ GTP-C port 2123 open
# ✅ GTP-U port 2152 open
# ✅ Metrics port 9090 responding
# ✅ Node Exporter port 9100 responding
# ✅ IP forwarding enabled
# ✅ ogstun interface exists
# ✅ Can reach VM3 (10.10.0.30)
# ✅ srsRAN installed
# ✅ eNB config exists
# ✅ UE config exists
```

### 5.2 Test VM2 (5G Core)

```bash
# Copy test script to VM2
scp scripts/test-vm2-5g.sh ayoubgory_gmail_com@$VM2_IP:/home/ayoubgory_gmail_com/

# Run test script
ssh ayoubgory_gmail_com@$VM2_IP "bash /home/ayoubgory_gmail_com/test-vm2-5g.sh"

# Expected results:
# ✅ MongoDB ping successful
# ✅ 5G subscriber found (IMSI: 999700000000001)
# ✅ open5gs-nrfd running
# ✅ open5gs-amfd running
# ✅ open5gs-smfd running
# ✅ open5gs-upfd running
# ✅ open5gs-udmd running
# ✅ open5gs-udrd running
# ✅ open5gs-pcfd running
# ✅ open5gs-ausfd running
# ✅ open5gs-nssfd running
# ✅ WebUI accessible on port 9999
# ✅ AMF NGAP port 38412 (SCTP) open
# ✅ NRF SBI port 7777 open
# ✅ UPF GTP-U port 2152 open
# ✅ Metrics port 9090 responding
# ✅ Node Exporter port 9100 responding
# ✅ NRF SBI responding
# ✅ IP forwarding enabled
# ✅ Can reach VM3 (10.10.0.30)
# ✅ UERANSIM installed
# ✅ gNB config exists
# ✅ UE config exists
```

### 5.3 Test VM3 (Monitoring)

```bash
# Copy test script to VM3
scp scripts/test-vm3-monitoring.sh ayoubgory_gmail_com@$VM3_IP:/home/ayoubgory_gmail_com/

# Run test script
ssh ayoubgory_gmail_com@$VM3_IP "bash /home/ayoubgory_gmail_com/test-vm3-monitoring.sh"

# Expected results:
# ✅ Prometheus service running
# ✅ Prometheus port 9090 open
# ✅ Prometheus health check passed
# ✅ Grafana service running
# ✅ Grafana port 3000 open
# ✅ Grafana health check passed
# ✅ Node Exporter port 9100 open
# ✅ Can reach VM1 (10.10.0.10)
# ✅ Can reach VM2 (10.10.0.20)
# ✅ VM1 Node Exporter accessible
# ✅ VM2 Node Exporter accessible
# ✅ Prometheus config exists
# ✅ Grafana config exists
# ✅ All 6 Prometheus targets UP
#   - prometheus: UP
#   - open5gs-4g-core: UP
#   - node-vm1-4g: UP
#   - open5gs-5g-core: UP
#   - node-vm2-5g: UP
#   - node-vm3-monitoring: UP
```

**✅ Checkpoint:** All VMs tested and verified

---

## 📋 Deployment Summary

### Infrastructure Deployed

| Component            | Status      | Details                                    |
| -------------------- | ----------- | ------------------------------------------ |
| **Network**          | ✅ Deployed | VPC, subnet, firewall, Cloud NAT           |
| **VM1 (4G)**         | ✅ Deployed | 10.10.0.10, Open5GS EPC, srsRAN, MongoDB   |
| **VM2 (5G)**         | ✅ Deployed | 10.10.0.20, Open5GS 5GC, UERANSIM, MongoDB |
| **VM3 (Monitoring)** | ✅ Deployed | 10.10.0.30, Prometheus, Grafana            |

### Access Points

```bash
# Grafana Dashboard (unified 4G vs 5G view)
http://$VM3_IP:3000
Login: admin / admin

# Prometheus (raw metrics)
http://$VM3_IP:9090

# VM1 WebUI (4G subscribers)
http://$VM1_IP:9999

# VM2 WebUI (5G subscribers)
http://$VM2_IP:9999
```

### Network Configuration

**4G Network (VM1):**

- **PLMN**: MCC=001, MNC=01, TAC=1
- **IMSI**: 001010000000001
- **K**: 465B5CE8B199B49FAA5F0A2EE238A6BC
- **OPc**: E8ED289DEBA952E4283B54E88E6183CA
- **APN**: internet
- **Subnet**: 10.45.0.0/16

**5G Network (VM2):**

- **PLMN**: MCC=999, MNC=70, TAC=1
- **IMSI**: 999700000000001
- **K**: 465B5CE8B199B49FAA5F0A2EE238A6BC
- **OPc**: E8ED289DEBA952E4283B54E88E6183CA
- **DNN**: internet
- **SST**: 1
- **Subnet**: 10.45.0.0/16

---

## 🔍 Troubleshooting

### VM1 (4G Core) Issues

```bash
# Check MME logs
ssh ayoubgory_gmail_com@$VM1_IP
sudo journalctl -u open5gs-mmed -n 50 -f

# Check MongoDB connection
mongosh open5gs --eval "db.subscribers.find()"

# Verify network ports
sudo netstat -tlnup | grep -E "36412|2123|2152"

# Check ogstun interface
ip addr show ogstun
```

### VM2 (5G Core) Issues

```bash
# Check AMF logs
ssh ayoubgory_gmail_com@$VM2_IP
sudo journalctl -u open5gs-amfd -n 50 -f

# Check NRF registration
curl http://localhost:7777/nnrf-nfm/v1/nf-instances | jq .

# Verify network ports
sudo netstat -tlnup | grep -E "38412|7777|2152"

# Check uesimtun0 interface (created when UE connects)
ip addr show uesimtun0
```

### VM3 (Monitoring) Issues

```bash
# Check Prometheus targets
ssh ayoubgory_gmail_com@$VM3_IP
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'

# Check Grafana logs
sudo journalctl -u grafana-server -n 50

# Test connectivity to VMs
ping -c 3 10.10.0.10
ping -c 3 10.10.0.20
curl http://10.10.0.10:9100/metrics | head
curl http://10.10.0.20:9100/metrics | head
```

### Common Issues

| Issue                         | Cause                     | Solution                               |
| ----------------------------- | ------------------------- | -------------------------------------- |
| Can't SSH to VM               | Firewall not configured   | Check GCP firewall rules allow port 22 |
| Ansible playbook fails        | Inventory not updated     | Update `ansible_host` with public IP   |
| MongoDB not accessible        | Service not started       | `sudo systemctl restart mongod`        |
| Open5GS service won't start   | Config error              | Check `/etc/open5gs/*.yaml` for syntax |
| VM3 can't scrape metrics      | Firewall blocks 9090/9100 | Check GCP internal firewall rules      |
| Prometheus shows targets DOWN | VMs not reachable         | Check `ping 10.10.0.10` from VM3       |

---

## ✅ Phase 1 Completion Checklist

- [ ] Network infrastructure deployed (VPC, subnet, firewall, NAT)
- [ ] VM1 created (10.10.0.10)
- [ ] VM1 software deployed (Open5GS EPC, srsRAN, MongoDB)
- [ ] VM1 tests passed (all services running, subscriber added)
- [ ] VM2 created (10.10.0.20)
- [ ] VM2 software deployed (Open5GS 5GC, UERANSIM, MongoDB)
- [ ] VM2 tests passed (all services running, subscriber added)
- [ ] VM3 created (10.10.0.30)
- [ ] VM3 software deployed (Prometheus, Grafana)
- [ ] VM3 tests passed (all 6 targets UP)
- [ ] Grafana dashboard accessible
- [ ] VM1 WebUI accessible
- [ ] VM2 WebUI accessible
- [ ] Inter-VM connectivity verified

**🎉 Phase 1 Complete!**

**Next Step:** Proceed to [PHASE-2-Testing-Benchmarking.md](PHASE-2-Testing-Benchmarking.md) for RAN testing and performance comparison.

---

## 📚 Additional Resources

- **Terraform Documentation**: Each `terraform-*/README.md` has detailed configuration info
- **Ansible Playbooks**: Review `ansible-*/playbooks/` for deployment details
- **Test Scripts**: See `scripts/test-vm*.sh` for verification logic
- **Open5GS Docs**: https://open5gs.org/open5gs/docs/
- **UERANSIM Docs**: https://github.com/aligungr/UERANSIM
- **srsRAN Docs**: https://docs.srsran.com/

