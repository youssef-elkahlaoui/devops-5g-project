# PHASE 2: DevOps, CI/CD & Automation (VM-Based)

**⏱️ Duration: 3-4 Hours | 🎯 Goal: Automate deployment with Terraform, Ansible, and CI/CD**

---

## ⚠️ IMPORTANT NOTE

**Phase 2 is OPTIONAL for academic projects.** If you completed Phase 1 manually and everything works, you can:

1. **Skip directly to Phase 3** for monitoring and benchmarking
2. **OR** Complete Phase 2 to learn DevOps/IaC concepts

Phase 2 provides automation for **repeatable deployments** - useful if you need to recreate the environment multiple times.

---

## 📋 Phase 2 Overview

In this phase, you will:

1. Create Terraform Infrastructure as Code (IaC)
2. Build Ansible playbooks for configuration automation
3. Set up CI/CD pipelines with GitHub Actions
4. Deploy UERANSIM for RAN simulation and testing
5. Implement automated health checks

**Result:** Fully automated, reproducible deployment pipeline

---

## ✅ Prerequisites

- ✅ Phase 1 completed (all VMs running)
- ✅ SSH access to all VMs working
- ✅ GitHub account for CI/CD
- ✅ Terraform and Ansible installed locally

```bash
# Verify prerequisites
terraform --version  # >= 1.5
ansible --version    # >= 2.14
gcloud auth list     # Authenticated
```

---

## 🏗️ STEP 1: Terraform Infrastructure as Code (60 minutes)

### 1.1 Create Project Structure

```bash
# Create directory structure
mkdir -p terraform ansible/inventory ansible/playbooks ansible/templates
mkdir -p scripts configs/open5gs configs/ueransim
mkdir -p .github/workflows

cd terraform
```

### 1.2 Create terraform/variables.tf

```bash
cat > variables.tf << 'EOF'
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "control_plane_ip" {
  description = "Control Plane VM private IP"
  type        = string
  default     = "10.10.0.2"
}

variable "user_plane_ip" {
  description = "User Plane VM private IP"
  type        = string
  default     = "10.11.0.7"
}

variable "db_ip" {
  description = "Database VM private IP"
  type        = string
  default     = "10.10.0.4"
}

variable "monitoring_ip" {
  description = "Monitoring VM private IP"
  type        = string
  default     = "10.10.0.50"
}

variable "ran_ip" {
  description = "RAN Simulator VM private IP"
  type        = string
  default     = "10.10.0.100"
}

variable "mcc" {
  description = "Mobile Country Code"
  type        = string
  default     = "999"
}

variable "mnc" {
  description = "Mobile Network Code"
  type        = string
  default     = "70"
}

variable "tac" {
  description = "Tracking Area Code"
  type        = number
  default     = 1
}
EOF
```

### 1.3 Create terraform/main.tf

```bash
cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ================================
#         VPC Network
# ================================
resource "google_compute_network" "open5gs_vpc" {
  name                    = "open5gs-vpc"
  auto_create_subnetworks = false
  description             = "Open5GS Core Network VPC"
}

# Control Plane Subnet
resource "google_compute_subnetwork" "control_subnet" {
  name          = "control-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.open5gs_vpc.id
  description   = "Control Plane and Signaling"
}

# User Plane Subnet
resource "google_compute_subnetwork" "data_subnet" {
  name          = "data-subnet"
  ip_cidr_range = "10.11.0.0/24"
  region        = var.region
  network       = google_compute_network.open5gs_vpc.id
  description   = "User Plane Data Traffic"
}

# ================================
#         Firewall Rules
# ================================
resource "google_compute_firewall" "allow_ssh" {
  name    = "open5gs-allow-ssh"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_sctp" {
  name    = "open5gs-allow-sctp"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "sctp"
    ports    = ["36412", "38412"]
  }
  source_ranges = ["10.10.0.0/24", "10.11.0.0/24"]
}

resource "google_compute_firewall" "allow_gtpu" {
  name    = "open5gs-allow-gtpu"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "udp"
    ports    = ["2152"]
  }
  source_ranges = ["10.10.0.0/24", "10.11.0.0/24"]
}

resource "google_compute_firewall" "allow_sbi" {
  name    = "open5gs-allow-sbi"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["7777"]
  }
  source_ranges = ["10.10.0.0/24"]
}

resource "google_compute_firewall" "allow_diameter" {
  name    = "open5gs-allow-diameter"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3868"]
  }
  allow {
    protocol = "sctp"
    ports    = ["3868"]
  }
  source_ranges = ["10.10.0.0/24"]
}

resource "google_compute_firewall" "allow_webui" {
  name    = "open5gs-allow-webui"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["9999"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_mongodb" {
  name    = "open5gs-allow-mongodb"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }
  source_ranges = ["10.10.0.0/24"]
}

resource "google_compute_firewall" "allow_monitoring" {
  name    = "open5gs-allow-monitoring"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["9090", "3000"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_internal" {
  name    = "open5gs-allow-internal"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["10.10.0.0/24", "10.11.0.0/24"]
}

# ================================
#         Compute Instances
# ================================

# Database VM
resource "google_compute_instance" "db" {
  name         = "open5gs-db"
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["database", "open5gs"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.control_subnet.name
    network_ip = var.db_ip
    access_config {}
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Control Plane VM
resource "google_compute_instance" "control" {
  name         = "open5gs-control"
  machine_type = "n2-standard-4"
  zone         = var.zone
  tags         = ["control-plane", "open5gs"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.control_subnet.name
    network_ip = var.control_plane_ip
    access_config {}
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# User Plane VM
resource "google_compute_instance" "userplane" {
  name         = "open5gs-userplane"
  machine_type = "c2-standard-4"
  zone         = var.zone
  tags         = ["user-plane", "open5gs"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.data_subnet.name
    network_ip = var.user_plane_ip
    access_config {}
  }

  can_ip_forward = true

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Monitoring VM
resource "google_compute_instance" "monitoring" {
  name         = "open5gs-monitoring"
  machine_type = "e2-standard-2"
  zone         = var.zone
  tags         = ["monitoring", "open5gs"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.control_subnet.name
    network_ip = var.monitoring_ip
    access_config {}
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# RAN Simulator VM
resource "google_compute_instance" "ran" {
  name         = "open5gs-ran"
  machine_type = "n2-standard-2"
  zone         = var.zone
  tags         = ["ran-simulator", "open5gs"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.control_subnet.name
    network_ip = var.ran_ip
    access_config {}
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}
EOF
```

### 1.4 Create terraform/outputs.tf

```bash
cat > outputs.tf << 'EOF'
output "db_external_ip" {
  value = google_compute_instance.db.network_interface[0].access_config[0].nat_ip
}

output "control_external_ip" {
  value = google_compute_instance.control.network_interface[0].access_config[0].nat_ip
}

output "userplane_external_ip" {
  value = google_compute_instance.userplane.network_interface[0].access_config[0].nat_ip
}

output "monitoring_external_ip" {
  value = google_compute_instance.monitoring.network_interface[0].access_config[0].nat_ip
}

output "ran_external_ip" {
  value = google_compute_instance.ran.network_interface[0].access_config[0].nat_ip
}

output "webui_url" {
  value = "http://${google_compute_instance.monitoring.network_interface[0].access_config[0].nat_ip}:9999"
}

output "grafana_url" {
  value = "http://${google_compute_instance.monitoring.network_interface[0].access_config[0].nat_ip}:3000"
}
EOF
```

### 1.5 Create terraform/terraform.tfvars

```bash
cat > terraform.tfvars << 'EOF'
project_id       = "open5gs-deployment-prod"  # Change to your project ID
region           = "us-central1"
zone             = "us-central1-a"
control_plane_ip = "10.10.0.2"
user_plane_ip    = "10.11.0.7"
db_ip            = "10.10.0.4"
monitoring_ip    = "10.10.0.50"
ran_ip           = "10.10.0.100"
mcc              = "999"
mnc              = "70"
tac              = 1
EOF
```

### 1.6 Initialize and Apply Terraform

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan -out=tfplan

# Apply (creates all resources)
terraform apply tfplan

# Get outputs
terraform output
```

---

## 🤖 STEP 2: Ansible Automation (90 minutes)

### 2.1 Create Ansible Inventory

```bash
cd ../ansible

cat > inventory/hosts.ini << 'EOF'
[database]
open5gs-db ansible_host=10.10.0.4

[control_plane]
open5gs-control ansible_host=10.10.0.2

[user_plane]
open5gs-userplane ansible_host=10.11.0.7

[monitoring]
open5gs-monitoring ansible_host=10.10.0.50

[ran_simulator]
open5gs-ran ansible_host=10.10.0.100

[open5gs:children]
database
control_plane
user_plane
monitoring
ran_simulator

[open5gs:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
db_ip=10.10.0.4
control_ip=10.10.0.2
userplane_ip=10.11.0.7
mcc=999
mnc=70
tac=1
EOF
```

### 2.2 Create ansible.cfg

```bash
cat > ansible.cfg << 'EOF'
[defaults]
inventory = inventory/hosts.ini
host_key_checking = False
remote_user = ubuntu
private_key_file = ~/.ssh/id_rsa
timeout = 30
roles_path = roles
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 86400

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
EOF
```

### 2.3 Create MongoDB Deployment Playbook

```bash
cat > playbooks/deploy_mongodb.yml << 'EOF'
---
- name: Deploy MongoDB
  hosts: database
  become: yes
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install prerequisites
      apt:
        name:
          - gnupg
          - curl
        state: present

    - name: Add MongoDB GPG key
      shell: |
        curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
        gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
      args:
        creates: /usr/share/keyrings/mongodb-server-8.0.gpg

    - name: Add MongoDB repository
      apt_repository:
        repo: "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse"
        state: present
        filename: mongodb-org-8.0

    - name: Install MongoDB
      apt:
        name: mongodb-org
        state: present
        update_cache: yes

    - name: Configure MongoDB for remote access
      lineinfile:
        path: /etc/mongod.conf
        regexp: '^  bindIp:'
        line: '  bindIp: 0.0.0.0'
        backup: yes

    - name: Start and enable MongoDB
      systemd:
        name: mongod
        state: started
        enabled: yes

    - name: Wait for MongoDB to be ready
      wait_for:
        port: 27017
        delay: 5
        timeout: 60

    - name: Verify MongoDB
      command: mongosh --eval "db.adminCommand('ping')"
      register: mongo_ping
      changed_when: false

    - name: Display MongoDB status
      debug:
        msg: "MongoDB is running: {{ mongo_ping.stdout }}"
EOF
```

### 2.4 Create 4G Core Deployment Playbook

```bash
cat > playbooks/deploy_4g.yml << 'EOF'
---
- name: Deploy 4G EPC
  hosts: control_plane
  become: yes
  vars:
    control_ip: "{{ hostvars['open5gs-control']['ansible_host'] }}"
    db_ip: "{{ hostvars['open5gs-db']['ansible_host'] }}"
    userplane_ip: "{{ hostvars['open5gs-userplane']['ansible_host'] }}"
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Add Open5GS PPA
      apt_repository:
        repo: ppa:open5gs/latest
        state: present

    - name: Install Open5GS
      apt:
        name: open5gs
        state: present
        update_cache: yes

    - name: Configure MME
      template:
        src: ../templates/mme.yaml.j2
        dest: /etc/open5gs/mme.yaml
        backup: yes
      notify: Restart MME

    - name: Configure HSS
      template:
        src: ../templates/hss.yaml.j2
        dest: /etc/open5gs/hss.yaml
        backup: yes
      notify: Restart HSS

    - name: Configure PCRF
      template:
        src: ../templates/pcrf.yaml.j2
        dest: /etc/open5gs/pcrf.yaml
        backup: yes
      notify: Restart PCRF

    - name: Configure SGW-C
      template:
        src: ../templates/sgwc.yaml.j2
        dest: /etc/open5gs/sgwc.yaml
        backup: yes
      notify: Restart SGWC

    - name: Configure SMF
      template:
        src: ../templates/smf.yaml.j2
        dest: /etc/open5gs/smf.yaml
        backup: yes
      notify: Restart SMF

    - name: Enable and start 4G services
      systemd:
        name: "{{ item }}"
        state: started
        enabled: yes
      loop:
        - open5gs-mmed
        - open5gs-hssd
        - open5gs-pcrfd
        - open5gs-sgwcd
        - open5gs-smfd

    - name: Wait for MME to be ready
      wait_for:
        port: 36412
        delay: 5
        timeout: 60

  handlers:
    - name: Restart MME
      systemd:
        name: open5gs-mmed
        state: restarted

    - name: Restart HSS
      systemd:
        name: open5gs-hssd
        state: restarted

    - name: Restart PCRF
      systemd:
        name: open5gs-pcrfd
        state: restarted

    - name: Restart SGWC
      systemd:
        name: open5gs-sgwcd
        state: restarted

    - name: Restart SMF
      systemd:
        name: open5gs-smfd
        state: restarted
EOF
```

### 2.5 Create 5G Core Deployment Playbook

```bash
cat > playbooks/deploy_5g.yml << 'EOF'
---
- name: Deploy 5G Core
  hosts: control_plane
  become: yes
  vars:
    control_ip: "{{ hostvars['open5gs-control']['ansible_host'] }}"
    db_ip: "{{ hostvars['open5gs-db']['ansible_host'] }}"
    userplane_ip: "{{ hostvars['open5gs-userplane']['ansible_host'] }}"
  tasks:
    - name: Configure NRF
      template:
        src: ../templates/nrf.yaml.j2
        dest: /etc/open5gs/nrf.yaml
        backup: yes
      notify: Restart NRF

    - name: Configure AMF
      template:
        src: ../templates/amf.yaml.j2
        dest: /etc/open5gs/amf.yaml
        backup: yes
      notify: Restart AMF

    - name: Configure UDM
      template:
        src: ../templates/udm.yaml.j2
        dest: /etc/open5gs/udm.yaml
        backup: yes
      notify: Restart UDM

    - name: Configure UDR
      template:
        src: ../templates/udr.yaml.j2
        dest: /etc/open5gs/udr.yaml
        backup: yes
      notify: Restart UDR

    - name: Configure PCF
      template:
        src: ../templates/pcf.yaml.j2
        dest: /etc/open5gs/pcf.yaml
        backup: yes
      notify: Restart PCF

    - name: Configure AUSF
      template:
        src: ../templates/ausf.yaml.j2
        dest: /etc/open5gs/ausf.yaml
        backup: yes
      notify: Restart AUSF

    - name: Configure NSSF
      template:
        src: ../templates/nssf.yaml.j2
        dest: /etc/open5gs/nssf.yaml
        backup: yes
      notify: Restart NSSF

    - name: Configure BSF
      template:
        src: ../templates/bsf.yaml.j2
        dest: /etc/open5gs/bsf.yaml
        backup: yes
      notify: Restart BSF

    - name: Start NRF first
      systemd:
        name: open5gs-nrfd
        state: started
        enabled: yes

    - name: Wait for NRF to be ready
      wait_for:
        port: 7777
        delay: 5
        timeout: 60

    - name: Enable and start 5G services
      systemd:
        name: "{{ item }}"
        state: started
        enabled: yes
      loop:
        - open5gs-amfd
        - open5gs-udmd
        - open5gs-udrd
        - open5gs-pcfd
        - open5gs-ausfd
        - open5gs-nssfd
        - open5gs-bsfd

    - name: Wait for AMF to be ready
      wait_for:
        port: 38412
        delay: 5
        timeout: 60

  handlers:
    - name: Restart NRF
      systemd:
        name: open5gs-nrfd
        state: restarted
    - name: Restart AMF
      systemd:
        name: open5gs-amfd
        state: restarted
    - name: Restart UDM
      systemd:
        name: open5gs-udmd
        state: restarted
    - name: Restart UDR
      systemd:
        name: open5gs-udrd
        state: restarted
    - name: Restart PCF
      systemd:
        name: open5gs-pcfd
        state: restarted
    - name: Restart AUSF
      systemd:
        name: open5gs-ausfd
        state: restarted
    - name: Restart NSSF
      systemd:
        name: open5gs-nssfd
        state: restarted
    - name: Restart BSF
      systemd:
        name: open5gs-bsfd
        state: restarted
EOF
```

### 2.6 Create User Plane Deployment Playbook

```bash
cat > playbooks/deploy_userplane.yml << 'EOF'
---
- name: Deploy User Plane
  hosts: user_plane
  become: yes
  vars:
    userplane_ip: "{{ hostvars['open5gs-userplane']['ansible_host'] }}"
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Add Open5GS PPA
      apt_repository:
        repo: ppa:open5gs/latest
        state: present

    - name: Install Open5GS
      apt:
        name: open5gs
        state: present
        update_cache: yes

    - name: Configure UPF
      template:
        src: ../templates/upf.yaml.j2
        dest: /etc/open5gs/upf.yaml
        backup: yes
      notify: Restart UPF

    - name: Configure SGW-U
      template:
        src: ../templates/sgwu.yaml.j2
        dest: /etc/open5gs/sgwu.yaml
        backup: yes
      notify: Restart SGWU

    - name: Enable IP forwarding
      sysctl:
        name: net.ipv4.ip_forward
        value: '1'
        sysctl_set: yes
        state: present
        reload: yes

    - name: Install iptables-persistent
      apt:
        name: iptables-persistent
        state: present

    - name: Configure NAT for 4G UE pool
      iptables:
        table: nat
        chain: POSTROUTING
        source: 10.45.0.0/16
        out_interface: "!ogstun"
        jump: MASQUERADE
      notify: Save iptables

    - name: Configure NAT for 5G UE pool
      iptables:
        table: nat
        chain: POSTROUTING
        source: 10.46.0.0/16
        out_interface: "!ogstun"
        jump: MASQUERADE
      notify: Save iptables

    - name: Allow ogstun input
      iptables:
        chain: INPUT
        in_interface: ogstun
        jump: ACCEPT
      notify: Save iptables

    - name: Allow ogstun forward in
      iptables:
        chain: FORWARD
        in_interface: ogstun
        jump: ACCEPT
      notify: Save iptables

    - name: Allow ogstun forward out
      iptables:
        chain: FORWARD
        out_interface: ogstun
        jump: ACCEPT
      notify: Save iptables

    - name: Enable and start user plane services
      systemd:
        name: "{{ item }}"
        state: started
        enabled: yes
      loop:
        - open5gs-upfd
        - open5gs-sgwud

    - name: Wait for UPF to be ready
      wait_for:
        port: 2152
        delay: 5
        timeout: 60

  handlers:
    - name: Restart UPF
      systemd:
        name: open5gs-upfd
        state: restarted

    - name: Restart SGWU
      systemd:
        name: open5gs-sgwud
        state: restarted

    - name: Save iptables
      command: netfilter-persistent save
EOF
```

### 2.7 Create AMF Template (Example)

```bash
cat > templates/amf.yaml.j2 << 'EOF'
amf:
  sbi:
    server:
      - address: {{ control_ip }}
        port: 7777
    client:
      scp:
        - uri: http://{{ control_ip }}:7777
      nrf:
        - uri: http://{{ control_ip }}:7777

  ngap:
    server:
      - address: {{ control_ip }}

  metrics:
    server:
      - address: {{ control_ip }}
        port: 9090

  guami:
    - plmn_id:
        mcc: {{ mcc }}
        mnc: {{ mnc }}
      amf_id:
        region: 2
        set: 1

  tai:
    - plmn_id:
        mcc: {{ mcc }}
        mnc: {{ mnc }}
      tac: {{ tac }}

  plmn_support:
    - plmn_id:
        mcc: {{ mcc }}
        mnc: {{ mnc }}
      s_nssai:
        - sst: 1
          sd: 000001
        - sst: 2
          sd: 000002

  security:
    integrity_order: [NIA2, NIA1, NIA0]
    ciphering_order: [NEA0, NEA1, NEA2]

  network_name:
    full: Open5GS

  amf_name: open5gs-amf0
EOF
```

### 2.8 Create UPF Template

```bash
cat > templates/upf.yaml.j2 << 'EOF'
upf:
  pfcp:
    server:
      - address: {{ userplane_ip }}

  gtpu:
    server:
      - address: {{ userplane_ip }}

  session:
    - subnet: 10.45.0.0/16
      gateway: 10.45.0.1
      dnn: internet
    - subnet: 10.46.0.0/16
      gateway: 10.46.0.1
      dnn: internet

  metrics:
    server:
      - address: {{ userplane_ip }}
        port: 9090
EOF
```

### 2.9 Create Master Deployment Playbook

```bash
cat > playbooks/deploy_all.yml << 'EOF'
---
- name: Deploy Complete Open5GS Infrastructure
  hosts: localhost
  gather_facts: no
  tasks:
    - name: Deploy MongoDB
      import_playbook: deploy_mongodb.yml

    - name: Deploy 4G Core
      import_playbook: deploy_4g.yml

    - name: Deploy 5G Core
      import_playbook: deploy_5g.yml

    - name: Deploy User Plane
      import_playbook: deploy_userplane.yml
EOF
```

### 2.10 Run Ansible Playbooks

```bash
# Test connectivity
ansible all -m ping

# Deploy step by step
ansible-playbook playbooks/deploy_mongodb.yml
ansible-playbook playbooks/deploy_4g.yml
ansible-playbook playbooks/deploy_5g.yml
ansible-playbook playbooks/deploy_userplane.yml

# Or deploy all at once
ansible-playbook playbooks/deploy_all.yml
```

---

## 🔄 STEP 3: CI/CD Pipeline with GitHub Actions (60 minutes)

### 3.1 Create Deploy Infrastructure Workflow

```bash
mkdir -p ../.github/workflows

cat > ../.github/workflows/deploy-infrastructure.yml << 'EOF'
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'
  workflow_dispatch:

env:
  TF_VERSION: '1.5.0'
  GCP_PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}

jobs:
  terraform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -out=tfplan -no-color
        continue-on-error: true

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan
EOF
```

### 3.2 Create Deploy Core Workflow

```bash
cat > ../.github/workflows/deploy-core.yml << 'EOF'
name: Deploy Open5GS Core

on:
  workflow_dispatch:
    inputs:
      component:
        description: 'Component to deploy'
        required: true
        type: choice
        options:
          - all
          - mongodb
          - 4g-core
          - 5g-core
          - userplane

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install Ansible
        run: |
          pip install ansible
          ansible --version

      - name: Setup SSH Key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Configure SSH ProxyJump
        run: |
          gcloud compute config-ssh --project=${{ secrets.GCP_PROJECT_ID }}

      - name: Deploy Component
        working-directory: ansible
        run: |
          case "${{ github.event.inputs.component }}" in
            all)
              ansible-playbook playbooks/deploy_all.yml
              ;;
            mongodb)
              ansible-playbook playbooks/deploy_mongodb.yml
              ;;
            4g-core)
              ansible-playbook playbooks/deploy_4g.yml
              ;;
            5g-core)
              ansible-playbook playbooks/deploy_5g.yml
              ;;
            userplane)
              ansible-playbook playbooks/deploy_userplane.yml
              ;;
          esac
EOF
```

### 3.3 Create Health Check Workflow

```bash
cat > ../.github/workflows/health-check.yml << 'EOF'
name: Health Check

on:
  schedule:
    - cron: '*/30 * * * *'  # Every 30 minutes
  workflow_dispatch:

jobs:
  health-check:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Setup gcloud
        uses: google-github-actions/setup-gcloud@v2
        with:
          project_id: ${{ secrets.GCP_PROJECT_ID }}

      - name: Check VMs Status
        run: |
          echo "=== VM Status ==="
          gcloud compute instances list --filter="name~open5gs" --format="table(name,status,networkInterfaces[0].networkIP)"

      - name: Check MME (4G)
        run: |
          echo "=== Checking MME ==="
          gcloud compute ssh open5gs-control --zone=us-central1-a --command="sudo ss -tlnp | grep 36412" || echo "MME not responding"

      - name: Check AMF (5G)
        run: |
          echo "=== Checking AMF ==="
          gcloud compute ssh open5gs-control --zone=us-central1-a --command="sudo ss -tlnp | grep 38412" || echo "AMF not responding"

      - name: Check UPF
        run: |
          echo "=== Checking UPF ==="
          gcloud compute ssh open5gs-userplane --zone=us-central1-a --command="sudo ss -ulnp | grep 2152" || echo "UPF not responding"

      - name: Check WebUI
        run: |
          echo "=== Checking WebUI ==="
          WEBUI_IP=$(gcloud compute instances describe open5gs-monitoring --zone=us-central1-a --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
          curl -s -o /dev/null -w "%{http_code}" http://${WEBUI_IP}:9999 || echo "WebUI not accessible"
EOF
```

---

## 📡 STEP 4: UERANSIM Deployment (30 minutes)

### 4.1 SSH into RAN Simulator VM

```bash
gcloud compute ssh open5gs-ran --zone=$ZONE
```

### 4.2 Install UERANSIM

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install build dependencies
sudo apt install -y make g++ libsctp-dev lksctp-tools iproute2

# Install cmake
sudo snap install cmake --classic

# Clone UERANSIM
cd ~
git clone https://github.com/aligungr/UERANSIM
cd UERANSIM

# Build
make

echo "✅ UERANSIM built successfully"
```

### 4.3 Configure 5G gNB

```bash
cat > config/open5gs-gnb.yaml << 'EOF'
mcc: '999'
mnc: '70'

nci: '0x000000010'
idLength: 32
tac: 1

linkIp: 10.10.0.100   # RAN VM IP
ngapIp: 10.10.0.100   # RAN VM IP
gtpIp: 10.10.0.100    # RAN VM IP

amfConfigs:
  - address: 10.10.0.2  # Control Plane VM IP
    port: 38412

slices:
  - sst: 1
    sd: 0x000001
  - sst: 2
    sd: 0x000002

ignoreStreamIds: true
EOF
```

### 4.4 Configure 5G UE

```bash
cat > config/open5gs-ue.yaml << 'EOF'
supi: 'imsi-999700000000002'
mcc: '999'
mnc: '70'

key: '465B5CE8B199B49FAA5F0A2EE238A6BC'
op: 'E8ED289DEBA952E4283B54E88E6183CA'
opType: 'OPC'
amf: '8000'

imei: '356938035643803'
imeiSv: '4370816125816151'

gnbSearchList:
  - 10.10.0.100

uacAic:
  mps: false
  mcs: false

uacAcc:
  normalClass: 0
  class11: false
  class12: false
  class13: false
  class14: false
  class15: false

sessions:
  - type: 'IPv4'
    apn: 'internet'
    slice:
      sst: 1
      sd: 0x000001

configured-nssai:
  - sst: 1
    sd: 0x000001

default-nssai:
  - sst: 1
    sd: 0x000001
EOF
```

### 4.5 Test 5G Connection

```bash
# Terminal 1: Start gNB
cd ~/UERANSIM
./build/nr-gnb -c config/open5gs-gnb.yaml

# Terminal 2: Start UE
cd ~/UERANSIM
sudo ./build/nr-ue -c config/open5gs-ue.yaml

# Terminal 3: Test connectivity
ping -I uesimtun0 8.8.8.8
```

### 4.6 Exit RAN VM

```bash
exit
```

---

## ✅ Phase 2 Validation Checklist

```
Terraform:
[✓] All resources defined in .tf files
[✓] terraform init succeeds
[✓] terraform validate passes
[✓] terraform plan shows expected resources
[✓] terraform apply creates infrastructure

Ansible:
[✓] Inventory file with all hosts
[✓] ansible all -m ping succeeds
[✓] MongoDB playbook deploys successfully
[✓] 4G Core playbook deploys successfully
[✓] 5G Core playbook deploys successfully
[✓] User Plane playbook deploys successfully

CI/CD:
[✓] GitHub workflows created
[✓] GCP secrets configured in GitHub
[✓] Infrastructure workflow runs
[✓] Core deployment workflow runs
[✓] Health check workflow scheduled

UERANSIM:
[✓] UERANSIM built successfully
[✓] gNB configuration created
[✓] UE configuration created
[✓] gNB connects to AMF
[✓] UE registers successfully
[✓] Data plane connectivity works
```

---

## 🛠️ Troubleshooting

### Ansible Connection Issues

```bash
# Test SSH connectivity
ssh -i ~/.ssh/id_rsa ubuntu@<EXTERNAL_IP>

# Test Ansible ping
ansible all -m ping -vvv

# Common fix: add host keys
ssh-keyscan <EXTERNAL_IP> >> ~/.ssh/known_hosts
```

### UERANSIM gNB Not Connecting

```bash
# Check AMF is listening
gcloud compute ssh open5gs-control --command="sudo ss -tlnp | grep 38412"

# Check firewall rules
gcloud compute firewall-rules list --filter="name~open5gs"

# Check SCTP connectivity from RAN
sudo apt install -y sctp-tools
sctp_test -H 10.10.0.100 -P 38412 -h 10.10.0.2 -p 38412 -s
```

### CI/CD Workflow Failures

```bash
# Check GitHub Actions logs
# Go to: Repository > Actions > Select workflow > View logs

# Verify secrets are set
# Go to: Repository > Settings > Secrets and variables > Actions

# Required secrets:
# - GCP_PROJECT_ID
# - GCP_SA_KEY (JSON key for service account)
# - SSH_PRIVATE_KEY
```

---

## 🎯 What's Next?

**Phase 2 Complete!** ✅

You now have:

- ✅ Terraform IaC for infrastructure
- ✅ Ansible automation for configuration
- ✅ CI/CD pipelines for deployment
- ✅ UERANSIM for RAN simulation

**Proceed to:** [PHASE-3-VM-Monitoring.md](PHASE-3-VM-Monitoring.md)

In Phase 3, you will:

- Set up Prometheus and Grafana monitoring
- Configure 5G network slicing (eMBB/URLLC)
- Run performance benchmarks
- Generate QoS/QoE reports

---

**Time Spent:** 3-4 hours | **Status:** Automation Complete
