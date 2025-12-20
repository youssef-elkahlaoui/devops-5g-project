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
#    VM1: 4G Core + srsRAN
# ================================
resource "google_compute_instance" "vm1_4g_core" {
  name         = "vm1-4g-core"
  machine_type = "e2-medium"  # 2vCPU, 4GB RAM
  zone         = "${var.region}-a"
  description  = "4G Core Network - Open5GS EPC + srsRAN eNB/UE"

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

    access_config {
      # Public IP for SSH and management
    }
  }

  metadata = {
    enable-oslogin = "true"
  }

  tags = ["open5gs", "4g-core", "srsran"]

  service_account {
    scopes = ["cloud-platform"]
  }
}
