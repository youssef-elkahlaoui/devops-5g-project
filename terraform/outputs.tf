output "vm_core_public_ip" {
  description = "Public IP of vm-core (for SSH access)"
  value       = google_compute_instance.vm_core.network_interface[0].access_config[0].nat_ip
}

output "vm_core_private_ip" {
  description = "Private IP of vm-core (Control Plane)"
  value       = google_compute_instance.vm_core.network_interface[0].network_ip
}

output "vm_ran_private_ip" {
  description = "Private IP of vm-ran (RAN Simulator)"
  value       = google_compute_instance.vm_ran.network_interface[0].network_ip
}

output "deployment_info" {
  description = "Deployment information"
  value = {
    vpc_name       = google_compute_network.open5gs_vpc.name
    control_subnet = google_compute_subnetwork.control_subnet.ip_cidr_range
    ssh_command    = "gcloud compute ssh ubuntu@vm-core --zone=us-central1-a"
  }
}
