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

# Control Plane Subnet (10.10.0.0/24)
resource "google_compute_subnetwork" "control_subnet" {
  name          = "control-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.open5gs_vpc.id
  description   = "Control Plane and Signaling"
}

# ================================
#         Firewall Rules
# ================================
# Critical: Allow ALL protocols for 5G (SCTP, GTP, HTTP/2, PFCP)
resource "google_compute_firewall" "allow_5g_lab" {
  name    = "allow-5g-lab"
  network = google_compute_network.open5gs_vpc.name
  description = "Allow all protocols for 5G lab (SCTP, GTP, HTTP/2, PFCP)"

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.open5gs_vpc.name
  description = "Allow SSH access"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# ================================
#         VM Core (5G Control Plane) - EXISTING, DO NOT RECREATE
# ================================
# This VM already exists with Open5GS 5GC + UERANSIM deployed
# Hosts unified Prometheus + Grafana for monitoring both 4G and 5G
resource "google_compute_instance" "vm_core" {
  name         = "vm-core"
  machine_type = "e2-medium"  # CRITICAL: 2vCPU, 4GB RAM minimum for stability
  zone         = "${var.region}-a"
  description  = "5G Core + Unified Monitoring - Open5GS 5GC + UERANSIM + Prometheus + Grafana"

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    network    = google_compute_network.open5gs_vpc.id
    subnetwork = google_compute_subnetwork.control_subnet.id
    network_ip = "10.10.0.2"

    access_config {
      # Public IP for SSH, Prometheus (9091), Grafana (3000)
    }
  }

  metadata = {
    enable-oslogin = "true"
  }

  tags = ["open5gs", "5g-core", "monitoring"]
  
  lifecycle {
    prevent_destroy = true  # Protect existing VM from accidental deletion
  }
}

# ================================
#         VM 4G Core (EPC) - NEW VM ONLY
# ================================
resource "google_compute_instance" "vm_4g_core" {
  name         = "vm-4g-core"
  machine_type = "e2-medium"  # 2vCPU, 4GB RAM for 4G EPC
  zone         = "${var.region}-a"
  description  = "4G Core Network - Open5GS EPC + srsRAN (metrics sent to vm-core)"

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    network    = google_compute_network.open5gs_vpc.id
    subnetwork = google_compute_subnetwork.control_subnet.id
    network_ip = "10.10.0.3"

    access_config {
      # Public IP for SSH and testing
    }
  }

  metadata = {
    enable-oslogin = "true"
  }

  tags = ["open5gs", "4g-core"]
}

# ================================
#         Outputs
# ================================