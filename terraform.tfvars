project_id       = "telecom5g-prod2"
region           = "us-central1"
cluster_name     = "telecom-dual-stack"
cluster_version  = "1.27"
node_count       = 2         # updated for multiple cores
machine_type     = "e2-medium"  # updated, smaller but enough for academic use
disk_size_gb     = 50        # updated, enough disk per node
db_instance_name = "telecom-postgres-prod"
db_version       = "15"
storage_bucket   = "telecom-backups-prod"
environment      = "development"

labels = {
  project     = "5g-4g-migration"
  team        = "telecom"
  environment = "development"
  created     = "2025-12-11"
}
