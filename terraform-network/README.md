# Terraform - Network Infrastructure

This folder creates the shared VPC network, subnet, firewall rules, and Cloud NAT for all VMs.

## What it Creates

- **VPC**: `open5gs-vpc`
- **Subnet**: `control-subnet` (10.10.0.0/24)
- **Firewall Rules**: SSH, SCTP, GTP-U/C, HTTP/2, Diameter, Monitoring, MongoDB
- **Cloud NAT**: Allows VMs to access internet

## Deploy

```bash
cd terraform-network
terraform init
terraform plan
terraform apply -auto-approve
```

## Outputs

- VPC name
- Subnet name and CIDR
- Region information

## Important

**Deploy this FIRST** before deploying any VM terraform configurations.
