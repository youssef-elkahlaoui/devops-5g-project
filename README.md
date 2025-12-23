# DevOps 4G/5G Core Network Deployment on GCP

## 3-VM Architecture: Isolated 4G, 5G, and Centralized Monitoring

**Project Status:** Production-Ready | 60-90 minutes (full deployment) | ~$20/month  
**Cloud Provider:** Google Cloud Platform (GCP)  
**Region:** us-central1-a  
**Project ID:** telecom5g-prod2-1

---

## Project Overview

This project deploys a complete 4G and 5G core network infrastructure on GCP with **3 dedicated VMs**, enabling side-by-side performance comparison and analysis.

### Architecture

```

                          GCP VPC: open5gs-vpc
                         Subnet: 10.10.0.0/24

  -
     VM1 (4G Core)        VM2 (5G Core)       VM3 (Monitoring)
     10.10.0.10           10.10.0.20           10.10.0.30

   Open5GS EPC          Open5GS 5GC          Prometheus
   srsRAN eNB/UE        UERANSIM gNB/UE      Grafana
   MongoDB              MongoDB              Node Exporter
   WebUI:9999           WebUI:9999
   Metrics:9090         Metrics:9090         Scrapes from:
   Node Exp:9100        Node Exp:9100         VM1 & VM2


```

For detailed documentation, see:

- **[PHASE-1-VM-Infrastructure.md](PHASE-1-VM-Infrastructure.md)** - Complete deployment guide
- **[PHASE-2-Testing-Benchmarking.md](PHASE-2-Testing-Benchmarking.md)** - Testing and performance analysis

---

## Quick Start

### Prerequisites

```bash
# Verify tools are installed
gcloud --version
terraform --version
ansible --version
```

### Step 1: Deploy Network (5 min)

```bash
cd terraform-network
terraform init && terraform apply -auto-approve
```

### Step 2: Deploy VM1 (4G Core) (15 min)

```bash
cd ../terraform-vm1-4g
terraform init && terraform apply -auto-approve
cd ../ansible-vm1-4g
ansible-playbook -i inventory/hosts.ini playbooks/deploy-4g-core.yml
```

### Step 3: Deploy VM2 (5G Core) (15 min)

```bash
cd ../terraform-vm2-5g
terraform init && terraform apply -auto-approve
cd ../ansible-vm2-5g
ansible-playbook -i inventory/hosts.ini playbooks/deploy-5g-core.yml
```

### Step 4: Deploy VM3 (Monitoring) (15 min)

```bash
cd ../terraform-vm3-monitoring
terraform init && terraform apply -auto-approve
cd ../ansible-vm3-monitoring
ansible-playbook -i inventory/hosts.ini playbooks/deploy-monitoring.yml
```

---

## VM Specifications

| VM      | Purpose       | IP         | Services                              |
| ------- | ------------- | ---------- | ------------------------------------- |
| **VM1** | 4G Core + RAN | 10.10.0.10 | Open5GS EPC, srsRAN, MongoDB, WebUI   |
| **VM2** | 5G Core + RAN | 10.10.0.20 | Open5GS 5GC, UERANSIM, MongoDB, WebUI |
| **VM3** | Monitoring    | 10.10.0.30 | Prometheus, Grafana                   |

---

## Testing

Each VM has a dedicated test script:

```bash
# Test VM1
ssh ayoubgory_gmail_com@<VM1-IP> "bash /home/ayoubgory_gmail_com/test-vm1-4g.sh"

# Test VM2
ssh ayoubgory_gmail_com@<VM2-IP> "bash /home/ayoubgory_gmail_com/test-vm2-5g.sh"

# Test VM3
ssh ayoubgory_gmail_com@<VM3-IP> "bash /home/ayoubgory_gmail_com/test-vm3-monitoring.sh"
```

---

## Monitoring

Access Grafana: `http://<VM3-PUBLIC-IP>:3000` (admin/admin)  
Access Prometheus: `http://<VM3-PUBLIC-IP>:9090`

---

## Project Structure

```
devops-5g-project/
 terraform-network/          # Shared VPC and firewall rules
 terraform-vm1-4g/           # VM1 (4G Core) infrastructure
 terraform-vm2-5g/           # VM2 (5G Core) infrastructure
 terraform-vm3-monitoring/   # VM3 (Monitoring) infrastructure
 ansible-vm1-4g/             # VM1 software deployment
 ansible-vm2-5g/             # VM2 software deployment
 ansible-vm3-monitoring/     # VM3 software deployment
 scripts/                    # Test scripts for each VM
 PHASE-1-VM-Infrastructure.md
 PHASE-2-Testing-Benchmarking.md
 README.md
```

---

## Troubleshooting

**VM1 Issues**: Check `/var/log/open5gs/mme.log`  
**VM2 Issues**: Check `/var/log/open5gs/amf.log`  
**VM3 Issues**: Check `http://localhost:9090/targets`

---

## Cleanup

```bash
cd terraform-vm3-monitoring && terraform destroy -auto-approve
cd ../terraform-vm2-5g && terraform destroy -auto-approve
cd ../terraform-vm1-4g && terraform destroy -auto-approve
cd ../terraform-network && terraform destroy -auto-approve
```
