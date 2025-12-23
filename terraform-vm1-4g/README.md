# Terraform - VM1 (4G Core)

This folder creates VM1 which hosts the 4G Core network and srsRAN simulator.

## What it Creates

- **VM**: `vm1-4g-core`
- **IP**: 10.10.0.10 (private) + public IP
- **Machine Type**: e2-medium (2vCPU, 4GB RAM)
- **Services**: Open5GS EPC (MME, SGW, PGW, HSS, PCRF) + srsRAN (eNB + UE)

## Prerequisites

Deploy `terraform-network` first to create VPC and firewall rules.

## Deploy

```bash
cd terraform-vm1-4g
terraform init
terraform plan
terraform apply -auto-approve
```

## Outputs

- VM1 public IP
- VM1 private IP
- SSH command

## Next Steps

After VM is created, deploy 4G software using `ansible-vm1-4g` playbooks.
