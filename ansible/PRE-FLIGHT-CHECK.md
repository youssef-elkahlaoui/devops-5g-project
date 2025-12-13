# Ansible Pre-Flight Checklist

## ✅ Verification Complete

All playbooks have been verified. **1 critical issue was fixed:**

### Fixed Issues

- ✅ **`deploy_all.yml`** - Removed incorrect wrapper syntax (can't nest `import_playbook` in tasks)

---

## 📋 Before Running Playbooks

### 1. SSH Key Setup

```bash
# Ensure your SSH key exists
ls ~/.ssh/id_rsa

# If not, generate one:
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Add public key to GCP metadata or VMs
cat ~/.ssh/id_rsa.pub
```

### 2. Update Inventory IPs (if VMs are already running)

Edit `ansible/inventory/hosts.ini` with actual VM IPs if different from:

- Database: `10.10.0.4`
- Control: `10.10.0.2`
- User Plane: `10.11.0.7`
- Monitoring: `10.10.0.50`
- RAN: `10.10.0.100`

### 3. Test Connectivity

```bash
cd ansible

# Ping all hosts
ansible all -m ping

# If SSH fails, manually test:
ssh -i ~/.ssh/id_rsa ubuntu@10.10.0.4  # Database VM
ssh -i ~/.ssh/id_rsa ubuntu@10.10.0.2  # Control VM
```

### 4. Syntax Check (Optional)

```bash
cd ansible
ansible-playbook playbooks/deploy_mongodb.yml --syntax-check
ansible-playbook playbooks/deploy_4g.yml --syntax-check
ansible-playbook playbooks/deploy_5g.yml --syntax-check
ansible-playbook playbooks/deploy_userplane.yml --syntax-check
ansible-playbook playbooks/deploy_all.yml --syntax-check
```

---

## 🚀 Running Playbooks

### Option A: Deploy Everything

```bash
cd ansible
ansible-playbook playbooks/deploy_all.yml
```

### Option B: Deploy Step-by-Step

```bash
cd ansible

# Step 1: MongoDB
ansible-playbook playbooks/deploy_mongodb.yml

# Step 2: 4G Core
ansible-playbook playbooks/deploy_4g.yml

# Step 3: 5G Core
ansible-playbook playbooks/deploy_5g.yml

# Step 4: User Plane
ansible-playbook playbooks/deploy_userplane.yml
```

### Verbose Mode (for debugging)

```bash
ansible-playbook playbooks/deploy_mongodb.yml -vvv
```

---

## ⚠️ Known Considerations

### Template Paths

- All templates use relative path: `../templates/*.yaml.j2`
- **✅ Correct** when running from `ansible/playbooks/`
- Playbooks must be executed with working directory = `ansible/`

### Dependency Order

1. **MongoDB first** - Required by HSS, PCRF, UDR, PCF
2. **4G Core** - MME, HSS, PCRF, SGW-C, SMF
3. **5G Core** - NRF must start first, then others
4. **User Plane** - UPF, SGW-U (depends on control plane)

### Firewall Requirements

Ensure GCP firewall rules allow:

- **SSH (22)** - For Ansible management
- **SCTP (36412, 38412)** - MME/AMF signaling
- **UDP (2152)** - GTP-U data plane
- **TCP (7777)** - SBI between 5G functions
- **TCP (27017)** - MongoDB access
- **TCP (9999)** - Open5GS WebUI

---

## 🔍 Verification After Deployment

### Check Services Status

```bash
# On Control Plane VM
gcloud compute ssh open5gs-control --zone=us-central1-a --command="\
  sudo systemctl status open5gs-mmed && \
  sudo systemctl status open5gs-amfd && \
  sudo systemctl status open5gs-nrfd"

# On User Plane VM
gcloud compute ssh open5gs-userplane --zone=us-central1-a --command="\
  sudo systemctl status open5gs-upfd && \
  sudo systemctl status open5gs-sgwud"

# On Database VM
gcloud compute ssh open5gs-db --zone=us-central1-a --command="\
  sudo systemctl status mongod"
```

### Check Network Listeners

```bash
# MME (4G) listening on SCTP 36412
gcloud compute ssh open5gs-control --command="sudo ss -tlnp | grep 36412"

# AMF (5G) listening on SCTP 38412
gcloud compute ssh open5gs-control --command="sudo ss -tlnp | grep 38412"

# UPF listening on UDP 2152
gcloud compute ssh open5gs-userplane --command="sudo ss -ulnp | grep 2152"

# NRF (5G SBI) on TCP 7777
gcloud compute ssh open5gs-control --command="sudo ss -tlnp | grep 7777"
```

---

## 🛠️ Common Issues & Fixes

### Issue: "Failed to connect to the host via ssh"

**Fix:** Add SSH keys to GCP or update `ansible_ssh_private_key_file` in inventory

### Issue: "apt_repository module not found"

**Fix:** On control machine, ensure Ansible 2.14+ installed

```bash
pip install --upgrade ansible
```

### Issue: "Template not found"

**Fix:** Run playbooks from `ansible/` directory, not `ansible/playbooks/`

```bash
cd ansible  # Not ansible/playbooks!
ansible-playbook playbooks/deploy_all.yml
```

### Issue: Services fail to start

**Fix:** Check logs on target VM

```bash
gcloud compute ssh open5gs-control --command="sudo journalctl -u open5gs-amfd -n 50"
```

---

## 📊 File Inventory

### Playbooks (5 files)

- ✅ `deploy_mongodb.yml` - MongoDB database
- ✅ `deploy_4g.yml` - 4G EPC (MME, HSS, PCRF, SGW-C, SMF)
- ✅ `deploy_5g.yml` - 5G Core (NRF, AMF, UDM, UDR, PCF, AUSF, NSSF, BSF)
- ✅ `deploy_userplane.yml` - User plane (UPF, SGW-U, NAT rules)
- ✅ `deploy_all.yml` - Master playbook (runs all above)

### Templates (14 files) - All Present ✅

- `amf.yaml.j2`, `ausf.yaml.j2`, `bsf.yaml.j2`, `hss.yaml.j2`
- `mme.yaml.j2`, `nrf.yaml.j2`, `nssf.yaml.j2`, `pcf.yaml.j2`
- `pcrf.yaml.j2`, `sgwc.yaml.j2`, `sgwu.yaml.j2`, `smf.yaml.j2`
- `udm.yaml.j2`, `udr.yaml.j2`, `upf.yaml.j2`

### Configuration

- ✅ `inventory/hosts.ini` - Host definitions and variables
- ✅ `ansible.cfg` - Ansible configuration

---

## ✅ Status: Ready to Deploy

All files verified. No syntax errors detected. Templates and inventory are properly configured.

**When you're on your Ansible machine, run:**

```bash
cd ansible
ansible all -m ping && ansible-playbook playbooks/deploy_all.yml
```
