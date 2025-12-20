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
#          VPC Network
# ================================
resource "google_compute_network" "open5gs_vpc" {
  name                    = "open5gs-vpc"
  auto_create_subnetworks = false
  description             = "Open5GS Core Network VPC (4G + 5G + Monitoring)"
}

# Control Plane Subnet (10.10.0.0/24)
resource "google_compute_subnetwork" "control_subnet" {
  name          = "control-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.open5gs_vpc.id
  description   = "Control Plane and Signaling (4G + 5G + Monitoring)"
}

# ================================
#          Firewall Rules
# ================================

# Allow SSH from anywhere
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.open5gs_vpc.name
  description = "Allow SSH access to all VMs"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  # FIXED TAGS
  target_tags   = ["open5gs", "core-4g", "core-5g", "monitoring"]
}

# Allow all internal communication within VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.open5gs_vpc.name
  description = "Allow all internal communication"

  allow {
    protocol = "all"
  }

  source_ranges = ["10.10.0.0/24"]
}

# Allow SCTP for S1-MME (4G) and NGAP (5G)
resource "google_compute_firewall" "allow_sctp" {
  name    = "allow-sctp"
  network = google_compute_network.open5gs_vpc.name
  description = "Allow SCTP for MME (36412) and AMF (38412)"

  allow {
    protocol = "sctp"
    ports    = ["36412", "38412"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["core-4g", "core-5g"]
}

# Allow GTP-U for user plane traffic
resource "google_compute_firewall" "allow_gtpu" {
  name    = "allow-gtpu"
  network = google_compute_network.open5gs_vpc.name
  description = "Allow GTP-U for UPF and SGW (2152)"

  allow {
    protocol = "udp"
    ports    = ["2152"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["core-4g", "core-5g"]
}

# Allow HTTP/2 for 5G SBI (Service Based Interface)
resource "google_compute_firewall" "allow_sbi" {
  name    = "allow-sbi"
  network = google_compute_network.open5gs_vpc.name
  description = "Allow HTTP/2 SBI communication (7777-7783)"

  allow {
    protocol = "tcp"
    ports    = ["7777", "7778", "7779", "7780", "7781", "7782", "7783"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["core-5g"]
}

# Allow Diameter for 4G (S6a, Gx interfaces)
resource "google_compute_firewall" "allow_diameter" {
  name    = "allow-diameter"
  network = google_compute_network.open5gs_vpc.name
  description = "Allow Diameter protocol (3868)"

  allow {
    protocol = "tcp"
    ports    = ["3868"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["core-4g"]
}

# Allow WebUI access (port 9999)
resource "google_compute_firewall" "allow_webui" {
  name    = "allow-webui"
  network = google_compute_network.open5gs_vpc.name
  description = "Allow Open5GS WebUI access (9999)"

  allow {
    protocol = "tcp"
    ports    = ["9999"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["core-4g", "core-5g"]
}

# Allow Prometheus/Grafana/Node Exporter
resource "google_compute_firewall" "allow_monitoring" {
  name    = "allow-monitoring"
  network = google_compute_network.open5gs_vpc.name
  description = "Allow monitoring access (Prometheus 9090, Grafana 3000, Node Exporter 9100)"

  allow {
    protocol = "tcp"
    ports    = ["3000", "9090", "9100"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["monitoring", "core-4g", "core-5g"]
}

# Allow PFCP for 4G SGW-C/SGW-U and 5G SMF/UPF
resource "google_compute_firewall" "allow_pfcp" {
  name    = "allow-pfcp"
  network = google_compute_network.open5gs_vpc.name
  description = "Allow PFCP protocol (8805)"

  allow {
    protocol = "udp"
    ports    = ["8805"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["core-4g", "core-5g"]
}

# Allow GTP-C for control plane
resource "google_compute_firewall" "allow_gtpc" {
  name    = "allow-gtpc"
  network = google_compute_network.open5gs_vpc.name
  description = "Allow GTP-C control plane (2123)"

  allow {
    protocol = "udp"
    ports    = ["2123"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["core-4g", "core-5g"]
}

# Allow MongoDB
resource "google_compute_firewall" "allow_mongodb" {
  name    = "allow-mongodb"
  network = google_compute_network.open5gs_vpc.name
  description = "Allow MongoDB access (27017)"

  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }

  source_ranges = ["10.10.0.0/24"]
  target_tags   = ["core-4g", "core-5g"]
}

# ================================
#          Cloud NAT
# ================================

resource "google_compute_router" "open5gs_router" {
  name    = "open5gs-router"
  network = google_compute_network.open5gs_vpc.id
  region  = var.region
}

resource "google_compute_router_nat" "open5gs_nat" {
  name                               = "open5gs-nat"
  router                             = google_compute_router.open5gs_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
