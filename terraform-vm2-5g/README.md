# Terraform - VM2 (5G Core)

This folder creates VM2 which hosts the 5G Core network and UERANSIM simulator.

## What it Creates

- **VM**: `vm2-5g-core`
- **IP**: 10.10.0.20 (private) + public IP
- **Machine Type**: e2-medium (2vCPU, 4GB RAM)
- **Services**: Open5GS 5GC (AMF, SMF, UPF, NRF, UDM, PCF, AUSF) + UERANSIM (gNB + UE)

## Prerequisites

Deploy `terraform-network` first to create VPC and firewall rules.

## Deploy

```bash
cd terraform-vm2-5g
terraform init
terraform plan
terraform apply -auto-approve
```

## Outputs

- VM2 public IP
- VM2 private IP
- SSH command

## Next Steps

After VM is created, deploy 5G software using `ansible-vm2-5g` playbooks.
