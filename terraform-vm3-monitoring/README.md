# Terraform - VM3 (Monitoring)

This folder creates VM3 which hosts the monitoring infrastructure (Prometheus + Grafana).

## What it Creates

- **VM**: `vm3-monitoring`
- **IP**: 10.10.0.30 (private) + public IP
- **Machine Type**: e2-medium (2vCPU, 4GB RAM)
- **Services**: Prometheus (port 9090) + Grafana (port 3000)

## Prerequisites

Deploy `terraform-network` first to create VPC and firewall rules.

## Deploy

```bash
cd terraform-vm3-monitoring
terraform init
terraform plan
terraform apply -auto-approve
```

## Outputs

- VM3 public IP
- VM3 private IP
- SSH command
- Grafana URL (http://public_ip:3000)
- Prometheus URL (http://public_ip:9090)

## Next Steps

After VM is created, deploy monitoring software using `ansible-vm3-monitoring` playbooks.
