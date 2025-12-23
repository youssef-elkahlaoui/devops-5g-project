output "vm2_public_ip" {
  description = "Public IP of VM2 (5G Core) for SSH access"
  value       = google_compute_instance.vm2_5g_core.network_interface[0].access_config[0].nat_ip
}

output "vm2_private_ip" {
  description = "Private IP of VM2 (5G Core)"
  value       = google_compute_instance.vm2_5g_core.network_interface[0].network_ip
}

output "vm2_ssh_command" {
  description = "SSH command to connect to VM2"
  value       = "gcloud compute ssh ubuntu@vm2-5g-core --zone=${var.region}-a"
}
