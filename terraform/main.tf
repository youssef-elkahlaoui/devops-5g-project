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
#         VM Core (Control Plane)
# ================================
resource "google_compute_instance" "vm_core" {
  name         = "vm-core"
  machine_type = "e2-medium"  # CRITICAL: 2vCPU, 4GB RAM minimum for stability
  zone         = "${var.region}-a"
  description  = "5G Core Network - NRF, AMF, SMF, UPF, MongoDB, Prometheus, Grafana"

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
      # Public IP for SSH access
    }
  }

  metadata = {
    enable-oslogin = "true"
  }

  tags = ["open5gs", "core"]
}

# ================================
#         VM RAN (Radio Access)
# ================================
resource "google_compute_instance" "vm_ran" {
  name         = "vm-ran"
  machine_type = "e2-medium"  # CRITICAL: 2vCPU, 4GB RAM for srsRAN compilation
  zone         = "${var.region}-a"
  description  = "RAN Simulator - srsRAN (4G) and UERANSIM (5G)"

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    network    = google_compute_network.open5gs_vpc.id
    subnetwork = google_compute_subnetwork.control_subnet.id
    network_ip = "10.10.0.100"
  }

  metadata = {
    enable-oslogin = "true"
  }

  tags = ["open5gs", "ran"]
}
# ================================