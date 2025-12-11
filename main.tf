terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket  = "telecom5g-prod-terraform-state2" # Ensure this bucket exists
    prefix  = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ================================
#         APIs
# ================================
# Ensure the Service Networking API is enabled (Required for Private SQL)
resource "google_project_service" "servicenetworking" {
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

# ================================
#         VPC & Subnet
# ================================
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = "10.20.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# ================================
#    Service Networking (Fix)
# ================================
# 1. Reserve an IP range for Google Services (Private SQL)
resource "google_compute_global_address" "private_ip_alloc" {
  name          = "${var.cluster_name}-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}
# 2. Create the VPC Peering connection
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  
  # CHANGE HERE: Use 'reserved_peering_ranges' and put the name in brackets []
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
  
  deletion_policy         = "ABANDON"

  depends_on = [google_project_service.servicenetworking]
}
# ================================
#         GKE Cluster
# ================================
resource "google_container_cluster" "telecom" {
  name                     = var.cluster_name
  location                 = var.region
  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = google_compute_network.vpc.name
  subnetwork               = google_compute_subnetwork.subnet.name
  resource_labels          = var.labels
}

# ================================
#         Node Pool
# ================================
resource "google_container_node_pool" "nodes" {
  name       = "${var.cluster_name}-pool-safe"
  cluster    = google_container_cluster.telecom.name
  location   = var.region
  node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 50
    disk_type    = "pd-standard"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    labels       = var.labels
    tags         = ["telecom", "kubernetes"]
  }
}

# ================================
#         Cloud SQL (Postgres)
# ================================
resource "random_password" "db_password" {
  length  = 24
  special = false # Sometimes special chars cause connection string issues, simpler is often safer
}

resource "google_sql_database_instance" "postgres" {
  name             = var.db_instance_name
  database_version = "POSTGRES_${var.db_version}"
  region           = var.region

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"

    backup_configuration {
      enabled = true
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }

    user_labels = var.labels
  }

  deletion_protection = false

  # CRITICAL: Wait for the VPC peering to be established before creating the instance
  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_database" "telecom" {
  name     = "telecom"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "telecom_user" {
  name     = "telecom"
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_password.result
}

# ================================
#         Cloud Storage Bucket
# ================================
resource "google_storage_bucket" "backups" {
  name          = "${var.project_id}-${var.storage_bucket}"
  location      = var.region
  force_destroy = true

  versioning {
    enabled = true
  }

  labels = var.labels
}

# ================================
#         Artifact Registry
# ================================
resource "google_artifact_registry_repository" "telecom" {
  location      = var.region
  repository_id = "telecom-images"
  format        = "DOCKER"
  labels        = var.labels
}

# ================================
#         Outputs
# ================================
output "cluster_name" {
  value = google_container_cluster.telecom.name
}

output "cloud_sql_instance" {
  value = google_sql_database_instance.postgres.connection_name
}

output "cloud_sql_password" {
  value     = random_password.db_password.result
  sensitive = true
}

output "storage_bucket" {
  value = google_storage_bucket.backups.name
}

output "artifact_registry" {
  value = google_artifact_registry_repository.telecom.repository_id
}
