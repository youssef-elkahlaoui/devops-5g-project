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
#    VM3: Monitoring Server
# ================================
resource "google_compute_instance" "vm3_monitoring" {
  name         = "vm3-monitoring"
  machine_type = "e2-medium"  # 2vCPU, 4GB RAM
  zone         = "${var.region}-a"
  description  = "Monitoring Server - Prometheus + Grafana (scrapes VM1 and VM2)"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    network    = var.vpc_network_name
    subnetwork = var.subnet_name
    network_ip = var.vm3_private_ip

    access_config {
      # Public IP for SSH, Prometheus, Grafana access
    }
  }

  metadata = {
    enable-oslogin = "true"
  }

  tags = ["monitoring", "prometheus", "grafana"]

  service_account {
    scopes = ["cloud-platform"]
  }
}
