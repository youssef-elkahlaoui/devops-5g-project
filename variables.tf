variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
  default     = "telecom-dual-stack"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.27"
}

variable "node_count" {
  description = "Number of nodes in cluster"
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Disk size for each node in GB"
  type        = number
  default     = 30
}

variable "db_instance_name" {
  description = "Cloud SQL instance name"
  type        = string
  default     = "telecom-postgres"
}

variable "db_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
}

variable "storage_bucket" {
  description = "Cloud Storage bucket name"
  type        = string
  default     = "telecom-backups"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "labels" {
  description = "GCP resource labels"
  type        = map(string)
  default = {
    project = "5g-migration"
    team    = "telecom"
  }
}
