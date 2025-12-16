# DevOps 5G Core on GCP - Infrastructure as Code

**Project Title:** Cloud-Native 5G Network with Network-as-Code  
**Project ID:** `telecom5g-prod2`  
**Cloud Zone:** `us-central1-a`  
**Status:** ✅ Production-Ready | ⏱️ 15-20 minutes (full deployment) | 💰 ~$10/month

---

## 🚀 Quick Start

```bash
# 1. Provision infrastructure
cd terraform
terraform init
terraform plan
terraform apply -auto-approve

# 2. Deploy Open5GS core
cd ../ansible
ansible-playbook -i inventory/hosts.ini playbooks/deploy-core.yml

# 3. Deploy UERANSIM RAN
ansible-playbook -i inventory/hosts.ini playbooks/deploy-ueransim.yml

# 4. Test connectivity
bash ../scripts/test-connectivity.sh
```

---

## 📂 Project Structure

```
devops-5g-project/
├── terraform/                          # Infrastructure as Code
│   ├── main.tf                        # VPC, subnets, firewall, VMs
│   ├── variables.tf                   # Input variables
│   └── outputs.tf                     # Deployment outputs
├── ansible/                           # Configuration Management
│   ├── ansible.cfg                    # Ansible configuration
│   ├── inventory/
│   │   └── hosts.ini                  # Managed hosts (control_plane, ran_nodes)
│   └── playbooks/
│       ├── deploy-core.yml            # Open5GS 5G core deployment
│       └── deploy-ueransim.yml        # UERANSIM RAN simulator compilation
├── scripts/                           # Testing & utilities
│   └── test-connectivity.sh           # Verify 5G UE attachment
├── PHASE-1-Infrastructure-Config.md   # Detailed setup guide
├── PHASE-2-Testing-Benchmarking.md    # Performance benchmarking
├── WORKING-CONFIG-REFERENCE.md        # All configuration details
└── README.md                          # This file
```

---

## 📖 Documentation

1. **[PHASE-1-Infrastructure-Config.md](PHASE-1-Infrastructure-Config.md)** - Infrastructure provisioning and core network setup
2. **[PHASE-2-Testing-Benchmarking.md](PHASE-2-Testing-Benchmarking.md)** - Performance benchmarking and observability setup
3. **[WORKING-CONFIG-REFERENCE.md](WORKING-CONFIG-REFERENCE.md)** - Complete configuration reference (PLMN, IMSI, keys, ports)

---


## 🏢 Executive Summary

This project demonstrates a modern **DevOps approach to telecommunications** by treating the mobile network as code (**Network as Code**). Rather than manually clicking in the GCP console, you automate the deployment of a dual-core network (supporting both legacy 4G LTE and standalone 5G SA) using:

- **Infrastructure as Code (Terraform)** - Provisions the cloud environment reproducibly
- **Configuration Management (Ansible)** - Deploys application stack idempotently
- **Comparative Benchmarking** - Analyzes performance (QoS) and resource efficiency
- **Observability** - Grafana dashboards demonstrating cloud-native advantages

The result is a scientific comparison proving why 5G is fundamentally suited for cloud deployment while 4G requires specialized hardware.

**Key Objectives:**

- ✅ Automate infrastructure provisioning with Terraform (Network as Code)
- ✅ Deploy application stack with Ansible (Configuration as Code)
- ✅ Dual-core network (4G EPC + 5G SA) running side-by-side
- ✅ Comparative performance benchmarking (QoS metrics)
- ✅ Prove 5G is cloud-efficient vs. 4G physical layer complexity
- ✅ Observability stack (Prometheus + Grafana) with actionable dashboards
- ✅ Production-ready, reproducible, and fully documented

---

## 🏗️ Architectural Strategy

### Two-Tier Separation of Duties

```
┌────────────────────────────────────────────────────────────────────┐
│             Google Cloud Platform (us-central1-a)                 │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  THE "BRAIN" (vm-core)    THE "EDGE" (vm-ran)                   │
│  ─────────────────────────  ────────────────────                 │
│  e2-medium (2vCPU/4GB)    e2-medium (2vCPU/4GB)                 │
│  10.10.0.2                10.10.0.100                            │
│                                                                    │
│  Control Plane:           RAN Simulators:                        │
│  • NRF (Discovery)        • srsRAN v22 (4G eNB+UE)              │
│  • AMF (Access Mgmt)      • UERANSIM v3.2 (5G gNB+UE)           │
│  • SMF (Session Mgmt)     • ZMQ mode (virtual antenna)           │
│  • UDM, UDR, PCF, AUSF                                          │
│  • UPF (User Plane)       Simulates backhaul latency            │
│                                                                    │
│  Database:                Observability:                         │
│  • MongoDB (subscribers)  • Node Exporter (metrics)             │
│  • Observability:         • Prometheus (scrape)                 │
│  • Prometheus (metrics)   • Grafana (visualization)             │
│  • Grafana (dashboards)                                         │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘

Why Separate VMs?
✓ Simulates real-world backhaul latency between RAN and Core
✓ Allows independent scaling and resource allocation
✓ Isolates Radio interference simulation from control logic
```

---

## 📁 Project Structure

```
devops-5g-project/
├── README.md                           # Project overview (this file)
├── PHASE-1-Infrastructure-Config.md    # Complete infrastructure guide
├── PHASE-2-Testing-Benchmarking.md     # Benchmarking & observability
├── WORKING-CONFIG-REFERENCE.md         # All configuration templates
├── DOCUMENTATION-INDEX.md              # Navigation guide
├── QUICK-START-CHEATSHEET.md           # Quick reference
├── MASTER-EXECUTION-ALIGNMENT.md       # Compliance checklist
├── IMPLEMENTATION-RESOURCES.md         # Where to get Terraform/Ansible code
├── .gitignore                          # Git ignore rules
└── .git/                               # Version control
```

**Pure Documentation Design** - All code is documented with links to official sources.

---

## 🚀 Quick Start

### Prerequisites

```bash
# You will need:
gcloud auth login          # Google Cloud authentication
gcloud config set project telecom5g-prod2
```

### Three-Step Deployment

**Step 1: Infrastructure (5-6 hours)**

Read and follow **[PHASE-1-Infrastructure-Config.md](PHASE-1-Infrastructure-Config.md)**

- Provisions 2 e2-medium VMs on GCP
- Installs Open5GS 5G Core Network
- Deploys RAN simulators (srsRAN, UERANSIM)
- All configuration documented step-by-step

**Step 2: Testing & Benchmarking (2-3 hours)**

Read and follow **[PHASE-2-Testing-Benchmarking.md](PHASE-2-Testing-Benchmarking.md)**

- Runs 4G vs 5G performance comparison
- Sets up Prometheus + Grafana observability
- Generates final report data

### Where to Get Implementation Code

**⚠️ Important:** We removed the legacy code folders to avoid confusion with the new architecture. Instead:

- **[IMPLEMENTATION-RESOURCES.md](IMPLEMENTATION-RESOURCES.md)** - Shows exactly where to get:
  - **Terraform** code snippets (write your own or use registry)
  - **Ansible** playbooks (examples provided)
  - **Test scripts** (manual or automated)
  - Links to official GitHub repos (Open5GS, UERANSIM, srsRAN)
  - Copy-paste templates for configs

**Quick Reference:** See [QUICK-START-CHEATSHEET.md](QUICK-START-CHEATSHEET.md) for commands

---

## 📊 Expected Performance

| Metric               | 4G        | 5G       | Improvement |
| -------------------- | --------- | -------- | ----------- |
| Registration Latency | 120-150ms | 40-60ms  | ↓ 60%       |
| Session Setup Time   | 80-100ms  | 25-35ms  | ↓ 68%       |
| User Plane Latency   | 15-20ms   | 5-8ms    | ↓ 60%       |
| Max Throughput       | 150 Mbps  | 800 Mbps | ↑ 433%      |

---

## 💰 Cost Estimate

**For 40 hours of development:**

- vm-core (e2-medium): $1.20
- vm-ran (e2-medium): $1.20
- Storage (100GB SSD): $6.80
- **Total: ~$15-20** (within GCP free tier)

---

## 📚 Technology Stack

| Layer            | Technology            | Version |
| ---------------- | --------------------- | ------- |
| **Cloud**        | Google Cloud Platform | Latest  |
| **IaC**          | Terraform             | >= 1.5  |
| **Config Mgmt**  | Ansible               | >= 2.10 |
| **Core Network** | Open5GS               | v2.7.6  |
| **4G RAN**       | srsRAN                | Latest  |
| **5G RAN**       | UERANSIM              | v3.2.6  |
| **Database**     | MongoDB               | 8.0     |
| **Monitoring**   | Prometheus + Grafana  | Latest  |

---

## 🔧 Key Features

✅ **Infrastructure as Code** - All infrastructure defined in Terraform  
✅ **Idempotent Configuration** - Run Ansible playbooks repeatedly  
✅ **Dual-Core Network** - 4G EPC and 5G SA running simultaneously  
✅ **Performance Benchmarking** - Automated load testing  
✅ **Real-Time Monitoring** - Prometheus metrics + Grafana dashboards  
✅ **Network Slicing** - eMBB, URLLC slice support  
✅ **Production-Ready** - Security, isolation, and best practices included

---

## 🛠️ Common Commands

```bash
# Deploy infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# Configure systems
cd ../ansible
ansible-playbook -i inventory.ini playbook-core.yml
ansible-playbook -i inventory.ini playbook-ran.yml

# SSH into VMs
gcloud compute ssh vm-core --zone=us-central1-a
gcloud compute ssh vm-ran --zone=us-central1-a --tunnel-through-iap

# View logs
journalctl -u open5gs-amfd -f
journalctl -u open5gs-smfd -f
```

---

## 🎯 Next Steps

1. **Start with Phase 1:** Read [PHASE-1-Infrastructure-Config.md](PHASE-1-Infrastructure-Config.md)
   - Provision infrastructure
   - Deploy Open5GS
   - Configure subscribers
2. **Then Phase 2:** Read [PHASE-2-Testing-Benchmarking.md](PHASE-2-Testing-Benchmarking.md)
   - Run performance tests
   - Set up monitoring
   - Analyze results

---

## 📖 Documentation References

- **Open5GS:** https://open5gs.org/open5gs/docs/
- **UERANSIM:** https://github.com/aligungr/UERANSIM
- **Terraform:** https://www.terraform.io/docs
- **Ansible:** https://docs.ansible.com/

---

## 📝 Notes

- This project is optimized for GCP free tier
- All documentation follows production best practices
- Code is version-controlled and reproducible
- Suitable for academic projects, DevOps portfolios, and learning

---

**Status:** Production-Ready | **Last Updated:** December 2025 | **Version:** 1.0
