#!/bin/bash
# Phase 2 Validation Script

echo "=========================================="
echo "       Phase 2 Validation Checklist       "
echo "=========================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_pass() {
    echo -e "${GREEN}[✓]${NC} $1"
}

check_fail() {
    echo -e "${RED}[✗]${NC} $1"
}

echo ""
echo "=== Terraform Checks ==="

if [ -f "terraform/main.tf" ]; then
    check_pass "main.tf exists"
else
    check_fail "main.tf missing"
fi

if [ -f "terraform/variables.tf" ]; then
    check_pass "variables.tf exists"
else
    check_fail "variables.tf missing"
fi

if [ -f "terraform/outputs.tf" ]; then
    check_pass "outputs.tf exists"
else
    check_fail "outputs.tf missing"
fi

if [ -f "terraform/terraform.tfvars" ]; then
    check_pass "terraform.tfvars exists"
else
    check_fail "terraform.tfvars missing"
fi

echo ""
echo "=== Ansible Checks ==="

if [ -f "ansible/inventory/hosts.ini" ]; then
    check_pass "Inventory file exists"
else
    check_fail "Inventory file missing"
fi

if [ -f "ansible/ansible.cfg" ]; then
    check_pass "ansible.cfg exists"
else
    check_fail "ansible.cfg missing"
fi

for playbook in deploy_mongodb deploy_4g deploy_5g deploy_userplane deploy_all; do
    if [ -f "ansible/playbooks/${playbook}.yml" ]; then
        check_pass "${playbook}.yml exists"
    else
        check_fail "${playbook}.yml missing"
    fi
done

echo ""
echo "=== Template Checks ==="

for template in amf upf nrf udm udr pcf ausf nssf bsf mme hss pcrf sgwc smf sgwu; do
    if [ -f "ansible/templates/${template}.yaml.j2" ]; then
        check_pass "${template}.yaml.j2 exists"
    else
        check_fail "${template}.yaml.j2 missing"
    fi
done

echo ""
echo "=== CI/CD Checks ==="

if [ -f ".github/workflows/deploy-infrastructure.yml" ]; then
    check_pass "deploy-infrastructure.yml exists"
else
    check_fail "deploy-infrastructure.yml missing"
fi

if [ -f ".github/workflows/deploy-core.yml" ]; then
    check_pass "deploy-core.yml exists"
else
    check_fail "deploy-core.yml missing"
fi

if [ -f ".github/workflows/health-check.yml" ]; then
    check_pass "health-check.yml exists"
else
    check_fail "health-check.yml missing"
fi

echo ""
echo "=== UERANSIM Config Checks ==="

if [ -f "configs/ueransim/open5gs-gnb.yaml" ]; then
    check_pass "gNB config exists"
else
    check_fail "gNB config missing"
fi

if [ -f "configs/ueransim/open5gs-ue.yaml" ]; then
    check_pass "UE config exists"
else
    check_fail "UE config missing"
fi

echo ""
echo "=========================================="
echo "        Validation Complete              "
echo "=========================================="