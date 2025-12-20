output "vm3_public_ip" {
  description = "Public IP of VM3 (Monitoring) for access"
  value       = google_compute_instance.vm3_monitoring.network_interface[0].access_config[0].nat_ip
}

output "vm3_private_ip" {
  description = "Private IP of VM3 (Monitoring)"
  value       = google_compute_instance.vm3_monitoring.network_interface[0].network_ip
}

output "vm3_ssh_command" {
  description = "SSH command to connect to VM3"
  value       = "gcloud compute ssh ubuntu@vm3-monitoring --zone=${var.region}-a"
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${google_compute_instance.vm3_monitoring.network_interface[0].access_config[0].nat_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${google_compute_instance.vm3_monitoring.network_interface[0].access_config[0].nat_ip}:9090"
}
