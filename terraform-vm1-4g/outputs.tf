output "vm1_public_ip" {
  description = "Public IP of VM1 (4G Core) for SSH access"
  value       = google_compute_instance.vm1_4g_core.network_interface[0].access_config[0].nat_ip
}

output "vm1_private_ip" {
  description = "Private IP of VM1 (4G Core)"
  value       = google_compute_instance.vm1_4g_core.network_interface[0].network_ip
}

output "vm1_ssh_command" {
  description = "SSH command to connect to VM1"
  value       = "gcloud compute ssh ubuntu@vm1-4g-core --zone=${var.region}-a"
}
