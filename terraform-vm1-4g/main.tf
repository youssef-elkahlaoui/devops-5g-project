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

# ==================================================
# VM1 - 4G Core (Open5GS EPC + srsRAN)
# ==================================================
resource "google_compute_instance" "vm1_4g_core" {
  name         = "vm1-4g-core"
  machine_type = "e2-medium"
  zone         = "${var.region}-a"

  description     = "4G Core Network - Open5GS EPC + srsRAN"
  can_ip_forward  = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    network    = var.vpc_network_name
    subnetwork = var.subnet_name
    network_ip = var.vm1_private_ip

    access_config {} # Public IP
  }

  tags = ["core-4g", "open5gs", "srsran"]

  metadata = {
    enable-oslogin = "false"
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}

# ==================================================
# Firewall rules for Open5GS + srsRAN
# ==================================================
resource "google_compute_firewall" "vm1_open5gs_fw" {
  name    = "vm1-open5gs-fw"
  network = var.vpc_network_name

  target_tags = ["core-4g"]
  source_ranges = ["10.10.0.0/24"] 

  allow {
    protocol = "tcp"
    ports    = ["22", "3000", "9090", "9092", "9999", "9100"]
  }

  allow {
    protocol = "udp"
    ports    = [
      "2123",
      "2152",
      "8805",
      "36412"
    ]
  }

  allow {
    protocol = "sctp"
    ports    = ["36412"]
  }
}
