output "vpc_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.open5gs_vpc.name
}

output "subnet_name" {
  description = "Name of the control subnet"
  value       = google_compute_subnetwork.control_subnet.name
}

output "subnet_cidr" {
  description = "CIDR of the control subnet"
  value       = google_compute_subnetwork.control_subnet.ip_cidr_range
}

output "network_info" {
  description = "Network deployment information"
  value = {
    vpc_name    = google_compute_network.open5gs_vpc.name
    subnet_name = google_compute_subnetwork.control_subnet.name
    subnet_cidr = google_compute_subnetwork.control_subnet.ip_cidr_range
    region      = var.region
  }
}
