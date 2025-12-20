variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "telecom5g-prod2"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "vpc_network_name" {
  description = "Name of the existing VPC network"
  type        = string
  default     = "open5gs-vpc"
}

variable "subnet_name" {
  description = "Name of the existing subnet"
  type        = string
  default     = "control-subnet"
}

variable "vm1_private_ip" {
  description = "Private IP for VM1 (4G Core)"
  type        = string
  default     = "10.10.0.10"
}
