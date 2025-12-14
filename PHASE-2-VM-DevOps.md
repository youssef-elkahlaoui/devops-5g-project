# PHASE 2: DevOps Layer for Existing Infrastructure

**⏱️ Duration: 2-3 Hours | 🎯 Goal: Add DevOps practices to your working 5G network**

---

> ⚠️ **PHASE 2 IS COMPLETELY OPTIONAL!**
>
> **Want monitoring instead?** You can skip Phase 2 entirely and jump directly from Phase 1 to Phase 3.
> Phase 3 only requires Phase 1 + BONUS (UERANSIM). See [PHASE-3-VM-Monitoring.md](PHASE-3-VM-Monitoring.md)

---

## 🎯 TWO PATHS - CHOOSE YOUR APPROACH

### ✅ **OPTION A: DevOps Layer on Existing Infrastructure** ⭐ RECOMMENDED

**👉 If you already completed Phase 1 and have a working 5G network, START HERE!**

This path adds professional DevOps practices to your existing infrastructure **WITHOUT rebuilding anything**:

- ✅ **Version control** for all configurations
- ✅ **Automated testing** framework for network validation
- ✅ **CI/CD pipeline** for safe configuration management
- ✅ **No downtime**, no resource waste, no rebuilding

**Jump directly to:** [Option A: DevOps Layer (Start Here!)](#option-a-devops-layer-for-existing-infrastructure)

---

### 🔄 **OPTION B: Full Infrastructure Automation** (Advanced)

**Only choose this if:** You need to deploy multiple 5G networks repeatedly, or want to learn full Infrastructure-as-Code from scratch.

This path **rebuilds everything** using Terraform and Ansible for full automation. **Warning:** Requires destroying your current working infrastructure.

**See:** [Option B: Full IaC Rebuild](#option-b-full-infrastructure-as-code-rebuild-advanced)

---

## 📋 What You'll Learn in Option A

In this phase, you will add DevOps best practices to your existing Phase 1 deployment:

1. **Git Repository Setup** - Version control for all configs and scripts
2. **Automated Testing Framework** - Scripts that validate your network health
3. **CI/CD Pipeline** - GitHub Actions for safe configuration deployment
4. **Health Monitoring** - Automated checks that run continuously
5. **Rollback Capability** - Safely revert bad configuration changes

**Result:** Production-grade DevOps practices on your working 5G network

---

# OPTION A: DevOps Layer for Existing Infrastructure

> **⚡ START HERE if you completed Phase 1!** This path adds DevOps practices WITHOUT rebuilding.

---

## ✅ Prerequisites

- ✅ **Phase 1 completed** - Working 5G network with internet connectivity
- ✅ **Git installed locally** (`git --version`)
- ✅ **GitHub account** (free tier is fine)
- ✅ **SSH access to all VMs** via `gcloud compute ssh`
- ✅ **Your local workspace:** `c:\Users\jozef\OneDrive\Desktop\devops-5g-project`

**Verify your Phase 1 is working:**

```bash
# Test UE connectivity through 5G network
gcloud compute ssh open5gs-ran --zone=us-central1-a --tunnel-through-iap \
  --command "ping -I uesimtun0 -c 4 8.8.8.8"

# Expected: 0% packet loss ✅
```

---

## 🏗️ STEP 1: Git Repository Setup (20 minutes)

### 1.1 Initialize Git Repository

From your local workspace:

```powershell
# Navigate to your project
cd C:\Users\jozef\OneDrive\Desktop\devops-5g-project

# Initialize Git repository
git init

# Create .gitignore
@"
# OS files
.DS_Store
Thumbs.db

# Credentials
*.key
*.pem
service-account*.json
credentials.json

# Terraform state (if you do Option B later)
terraform.tfstate
terraform.tfstate.backup
.terraform/

# Local test outputs
test-results/
logs/
*.log

# IDE
.vscode/
.idea/
"@ | Out-File -FilePath .gitignore -Encoding UTF8

# Initial commit
git add .
git commit -m "Initial commit: Phase 1 completed - Working 5G network"
```

### 1.2 Create GitHub Repository

1. Go to [https://github.com/new](https://github.com/new)
2. Repository name: `devops-5g-project`
3. Description: `Open5GS 5G Core Network on GCP with DevOps practices`
4. **Private** (recommended for academic work)
5. **Don't** initialize with README (we already have one)
6. Click **Create repository**

### 1.3 Connect Local to GitHub

```powershell
# Add remote (replace YOUR-USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR-USERNAME/devops-5g-project.git

# Set branch name
git branch -M main

# Push to GitHub
git push -u origin main
```

**✅ Checkpoint:** Your configurations are now version controlled!

---

## 🏗️ STEP 2: Create Configuration Backup Scripts (30 minutes)

### 2.1 Create Config Fetcher Script

Create `scripts/fetch-configs.sh`:

```bash
cat > scripts/fetch-configs.sh << 'EOF'
#!/bin/bash
# Fetch all Open5GS configurations from VMs

PROJECT_ID="telecom5g-prod2"
ZONE="us-central1-a"
CONFIG_DIR="configs/open5gs"

echo "📥 Fetching Open5GS configurations from GCP VMs..."

# Create directory structure
mkdir -p ${CONFIG_DIR}/{control,userplane,database}

# Fetch Control Plane configs
echo "🔹 Fetching Control Plane configs..."
gcloud compute ssh open5gs-control --zone=${ZONE} --tunnel-through-iap \
  --command "sudo tar czf /tmp/open5gs-configs.tar.gz /etc/open5gs/*.yaml" 2>/dev/null

gcloud compute scp open5gs-control:/tmp/open5gs-configs.tar.gz \
  ${CONFIG_DIR}/control/ --zone=${ZONE} --tunnel-through-iap 2>/dev/null

cd ${CONFIG_DIR}/control && tar xzf open5gs-configs.tar.gz --strip-components=3 && rm open5gs-configs.tar.gz
cd - > /dev/null

# Fetch User Plane configs
echo "🔹 Fetching User Plane configs..."
gcloud compute ssh open5gs-userplane --zone=${ZONE} --tunnel-through-iap \
  --command "sudo tar czf /tmp/upf-configs.tar.gz /etc/open5gs/upf.yaml" 2>/dev/null

gcloud compute scp open5gs-userplane:/tmp/upf-configs.tar.gz \
  ${CONFIG_DIR}/userplane/ --zone=${ZONE} --tunnel-through-iap 2>/dev/null

cd ${CONFIG_DIR}/userplane && tar xzf upf-configs.tar.gz --strip-components=3 && rm upf-configs.tar.gz
cd - > /dev/null

# Fetch MongoDB subscriber data
echo "🔹 Fetching MongoDB subscriber data..."
gcloud compute ssh open5gs-database --zone=${ZONE} --tunnel-through-iap \
  --command "mongosh open5gs --quiet --eval 'db.subscribers.find().forEach(printjson)'" \
  > ${CONFIG_DIR}/database/subscribers-export.json 2>/dev/null

echo "✅ Configuration backup complete!"
echo "📁 Configs saved to: ${CONFIG_DIR}/"

# Show what we got
find ${CONFIG_DIR} -type f -name "*.yaml" -o -name "*.json"
EOF

chmod +x scripts/fetch-configs.sh
```

### 2.2 Run Initial Backup

```bash
# Execute backup
bash scripts/fetch-configs.sh

# Commit to Git
git add configs/
git commit -m "Backup: Open5GS configurations from working Phase 1 deployment"
git push
```

**✅ Checkpoint:** All your working configurations are now backed up and versioned!

---

## 🏗️ STEP 3: Automated Testing Framework (45 minutes)

### 3.1 Create Network Health Test Script

Create `scripts/test-network-health.sh`:

```bash
cat > scripts/test-network-health.sh << 'EOF'
#!/bin/bash
# Comprehensive 5G Network Health Check

PROJECT_ID="telecom5g-prod2"
ZONE="us-central1-a"
RESULTS_DIR="test-results"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULTS_FILE="${RESULTS_DIR}/health-check-${TIMESTAMP}.txt"

mkdir -p ${RESULTS_DIR}

echo "🔍 5G Network Health Check - $(date)" | tee ${RESULTS_FILE}
echo "========================================" | tee -a ${RESULTS_FILE}
echo "" | tee -a ${RESULTS_FILE}

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Helper function for test results
test_result() {
    local test_name=$1
    local result=$2
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ "$result" == "PASS" ]; then
        echo "✅ ${test_name}: PASS" | tee -a ${RESULTS_FILE}
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "❌ ${test_name}: FAIL" | tee -a ${RESULTS_FILE}
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# TEST 1: MongoDB Connection
echo "📊 Test 1/10: MongoDB Database Connection" | tee -a ${RESULTS_FILE}
MONGO_STATUS=$(gcloud compute ssh open5gs-database --zone=${ZONE} --tunnel-through-iap \
  --command "systemctl is-active mongod" 2>/dev/null)
[ "$MONGO_STATUS" == "active" ] && test_result "MongoDB Service" "PASS" || test_result "MongoDB Service" "FAIL"

# TEST 2: Control Plane Services (9 services for 5G)
echo "📊 Test 2/10: Control Plane Services (5G)" | tee -a ${RESULTS_FILE}
SERVICES=("nrfd" "smfd" "amfd" "udmd" "udrd" "pcfd" "ausfd" "nssfd" "bsfd")
CONTROL_PASS=true

for service in "${SERVICES[@]}"; do
    STATUS=$(gcloud compute ssh open5gs-control --zone=${ZONE} --tunnel-through-iap \
      --command "systemctl is-active open5gs-${service}" 2>/dev/null)
    if [ "$STATUS" != "active" ]; then
        echo "  ⚠️  open5gs-${service} is not active" | tee -a ${RESULTS_FILE}
        CONTROL_PASS=false
    fi
done

[ "$CONTROL_PASS" == true ] && test_result "Control Plane (9 services)" "PASS" || test_result "Control Plane (9 services)" "FAIL"

# TEST 3: User Plane Service
echo "📊 Test 3/10: User Plane Service" | tee -a ${RESULTS_FILE}
UPF_STATUS=$(gcloud compute ssh open5gs-userplane --zone=${ZONE} --tunnel-through-iap \
  --command "systemctl is-active open5gs-upfd" 2>/dev/null)
[ "$UPF_STATUS" == "active" ] && test_result "UPF Service" "PASS" || test_result "UPF Service" "FAIL"

# TEST 4: SMF-UPF PFCP Association
echo "📊 Test 4/10: SMF-UPF PFCP Association" | tee -a ${RESULTS_FILE}
PFCP_CHECK=$(gcloud compute ssh open5gs-control --zone=${ZONE} --tunnel-through-iap \
  --command "sudo journalctl -u open5gs-smfd -n 100 --no-pager | grep 'PFCP associated'" 2>/dev/null | tail -1)

if [[ "$PFCP_CHECK" == *"10.11.0.7"* ]]; then
    test_result "SMF-UPF PFCP Association" "PASS"
else
    test_result "SMF-UPF PFCP Association" "FAIL"
fi

# TEST 5: NRF Service Discovery
echo "📊 Test 5/10: NRF Service Discovery" | tee -a ${RESULTS_FILE}
NRF_CHECK=$(gcloud compute ssh open5gs-control --zone=${ZONE} --tunnel-through-iap \
  --command "curl -s http://127.0.0.20:7777/nnrf-nfm/v1/nf-instances | grep -c 'nfInstanceId'" 2>/dev/null)

if [ "$NRF_CHECK" -gt 5 ]; then
    test_result "NRF Service Discovery ($NRF_CHECK services)" "PASS"
else
    test_result "NRF Service Discovery" "FAIL"
fi

# TEST 6: MongoDB Subscriber Count
echo "📊 Test 6/10: MongoDB Subscriber Data" | tee -a ${RESULTS_FILE}
SUB_COUNT=$(gcloud compute ssh open5gs-database --zone=${ZONE} --tunnel-through-iap \
  --command "mongosh open5gs --quiet --eval 'db.subscribers.countDocuments()'" 2>/dev/null)

if [ "$SUB_COUNT" -gt 0 ]; then
    test_result "Subscriber Data ($SUB_COUNT subscribers)" "PASS"
else
    test_result "Subscriber Data" "FAIL"
fi

# TEST 7: Port Conflict Check (4G services should be disabled)
echo "📊 Test 7/10: Port Conflict Check" | tee -a ${RESULTS_FILE}
PORT_8805=$(gcloud compute ssh open5gs-userplane --zone=${ZONE} --tunnel-through-iap \
  --command "sudo ss -ulnp | grep ':8805' | grep -c upf" 2>/dev/null)

[ "$PORT_8805" -gt 0 ] && test_result "Port 8805 (UPF only)" "PASS" || test_result "Port 8805 (UPF only)" "FAIL"

# TEST 8: UERANSIM gNB Status
echo "📊 Test 8/10: UERANSIM gNB Status" | tee -a ${RESULTS_FILE}
GNB_PROC=$(gcloud compute ssh open5gs-ran --zone=${ZONE} --tunnel-through-iap \
  --command "pgrep -f 'nr-gnb'" 2>/dev/null)

if [ ! -z "$GNB_PROC" ]; then
    test_result "gNB Process Running" "PASS"
else
    test_result "gNB Process Running" "FAIL"
fi

# TEST 9: UERANSIM UE Status
echo "📊 Test 9/10: UERANSIM UE Status" | tee -a ${RESULTS_FILE}
UE_PROC=$(gcloud compute ssh open5gs-ran --zone=${ZONE} --tunnel-through-iap \
  --command "pgrep -f 'nr-ue'" 2>/dev/null)

if [ ! -z "$UE_PROC" ]; then
    test_result "UE Process Running" "PASS"
else
    test_result "UE Process Running" "FAIL"
fi

# TEST 10: End-to-End Connectivity
echo "📊 Test 10/10: End-to-End Internet Connectivity" | tee -a ${RESULTS_FILE}
PING_TEST=$(gcloud compute ssh open5gs-ran --zone=${ZONE} --tunnel-through-iap \
  --command "timeout 10 ping -I uesimtun0 -c 4 8.8.8.8 2>/dev/null | grep -c 'bytes from'" 2>/dev/null)

if [ "$PING_TEST" -ge 3 ]; then
    test_result "Internet Connectivity (4/4 pings)" "PASS"
else
    test_result "Internet Connectivity" "FAIL"
fi

# Summary
echo "" | tee -a ${RESULTS_FILE}
echo "========================================" | tee -a ${RESULTS_FILE}
echo "📊 TEST SUMMARY" | tee -a ${RESULTS_FILE}
echo "========================================" | tee -a ${RESULTS_FILE}
echo "Total Tests:  ${TOTAL_TESTS}" | tee -a ${RESULTS_FILE}
echo "Passed:       ${PASSED_TESTS} ✅" | tee -a ${RESULTS_FILE}
echo "Failed:       ${FAILED_TESTS} ❌" | tee -a ${RESULTS_FILE}
echo "Success Rate: $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%" | tee -a ${RESULTS_FILE}
echo "" | tee -a ${RESULTS_FILE}

if [ ${FAILED_TESTS} -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED! Network is healthy." | tee -a ${RESULTS_FILE}
    exit 0
else
    echo "⚠️  Some tests failed. Check logs for details." | tee -a ${RESULTS_FILE}
    exit 1
fi
EOF

chmod +x scripts/test-network-health.sh
```

### 3.2 Run Your First Automated Test

```bash
# Run the test suite
bash scripts/test-network-health.sh

# Expected output: 10/10 tests passed ✅
```

### 3.3 Create Quick Service Status Script

Create `scripts/quick-status.sh`:

```bash
cat > scripts/quick-status.sh << 'EOF'
#!/bin/bash
# Quick status check for all VMs

PROJECT_ID="telecom5g-prod2"
ZONE="us-central1-a"

echo "🔍 Quick 5G Network Status Check"
echo "=================================="
echo ""

# Database VM
echo "📊 Database VM (MongoDB):"
gcloud compute ssh open5gs-database --zone=${ZONE} --tunnel-through-iap \
  --command "systemctl is-active mongod && mongosh open5gs --quiet --eval 'db.subscribers.countDocuments()' 2>/dev/null | tail -1 | xargs echo 'Subscribers:'" 2>/dev/null
echo ""

# Control Plane VM
echo "📊 Control Plane VM (5G Core Services):"
gcloud compute ssh open5gs-control --zone=${ZONE} --tunnel-through-iap \
  --command "systemctl is-active open5gs-{nrfd,smfd,amfd,udmd,udrd,pcfd,ausfd,nssfd,bsfd} 2>/dev/null | grep -c active | xargs echo 'Active Services:'" 2>/dev/null
echo ""

# User Plane VM
echo "📊 User Plane VM (UPF):"
gcloud compute ssh open5gs-userplane --zone=${ZONE} --tunnel-through-iap \
  --command "systemctl is-active open5gs-upfd && sudo ss -ulnp | grep ':8805' | grep -c upf | xargs echo 'UPF on port 8805:'" 2>/dev/null
echo ""

# RAN VM
echo "📊 RAN VM (UERANSIM):"
gcloud compute ssh open5gs-ran --zone=${ZONE} --tunnel-through-iap \
  --command "pgrep -f 'nr-gnb' >/dev/null && echo 'gNB: Running ✅' || echo 'gNB: Stopped ❌'; pgrep -f 'nr-ue' >/dev/null && echo 'UE: Running ✅' || echo 'UE: Stopped ❌'" 2>/dev/null
echo ""

# Connectivity test
echo "📊 Internet Connectivity:"
gcloud compute ssh open5gs-ran --zone=${ZONE} --tunnel-through-iap \
  --command "timeout 5 ping -I uesimtun0 -c 2 8.8.8.8 2>/dev/null | tail -2 | head -1" 2>/dev/null || echo "❌ Connectivity test failed"

echo ""
echo "=================================="
EOF

chmod +x scripts/quick-status.sh
```

### 3.4 Commit Testing Framework

```bash
# Add test scripts
git add scripts/
git add test-results/.gitkeep
git commit -m "Add automated testing framework for network health monitoring"
git push
```

**✅ Checkpoint:** You now have automated tests that validate your entire 5G network!

---

## 🏗️ STEP 4: CI/CD Pipeline with GitHub Actions (40 minutes)

### 4.1 Create GitHub Actions Workflow Directory

```powershell
# Create workflows directory
mkdir .github\workflows
```

### 4.2 Create Configuration Deployment Workflow

Create `.github/workflows/deploy-config.yml`:

```yaml
cat > .github/workflows/deploy-config.yml << 'EOF'
name: Deploy Open5GS Configuration

on:
  push:
    branches:
      - main
    paths:
      - 'configs/open5gs/**'
  workflow_dispatch:

env:
  PROJECT_ID: telecom5g-prod2
  ZONE: us-central1-a

jobs:
  validate-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup GCloud CLI
        uses: google-github-actions/setup-gcloud@v2
        with:
          service_account_key: ${{ secrets.GCP_SA_KEY }}
          project_id: ${{ env.PROJECT_ID }}

      - name: Validate YAML Syntax
        run: |
          echo "🔍 Validating YAML configuration files..."
          for file in configs/open5gs/**/*.yaml; do
            echo "Checking $file..."
            python3 -c "import yaml; yaml.safe_load(open('$file'))" || exit 1
          done
          echo "✅ All YAML files are valid"

      - name: Backup Current Configs
        run: |
          echo "📦 Creating backup of current configurations..."
          mkdir -p backups
          timestamp=$(date +%Y%m%d-%H%M%S)

          gcloud compute ssh open5gs-control --zone=${{ env.ZONE }} --tunnel-through-iap \
            --command "sudo tar czf /tmp/backup-${timestamp}.tar.gz /etc/open5gs/*.yaml"

          gcloud compute scp open5gs-control:/tmp/backup-${timestamp}.tar.gz \
            backups/ --zone=${{ env.ZONE }} --tunnel-through-iap

          echo "✅ Backup created: backup-${timestamp}.tar.gz"

      - name: Deploy Control Plane Configs
        run: |
          echo "🚀 Deploying Control Plane configurations..."

          gcloud compute scp configs/open5gs/control/*.yaml \
            open5gs-control:/tmp/ --zone=${{ env.ZONE }} --tunnel-through-iap

          gcloud compute ssh open5gs-control --zone=${{ env.ZONE }} --tunnel-through-iap \
            --command "sudo cp /tmp/*.yaml /etc/open5gs/ && sudo chown root:root /etc/open5gs/*.yaml"

          echo "✅ Control Plane configs deployed"

      - name: Deploy User Plane Configs
        run: |
          echo "🚀 Deploying User Plane configurations..."

          gcloud compute scp configs/open5gs/userplane/upf.yaml \
            open5gs-userplane:/tmp/ --zone=${{ env.ZONE }} --tunnel-through-iap

          gcloud compute ssh open5gs-userplane --zone=${{ env.ZONE }} --tunnel-through-iap \
            --command "sudo cp /tmp/upf.yaml /etc/open5gs/ && sudo chown root:root /etc/open5gs/upf.yaml"

          echo "✅ User Plane configs deployed"

      - name: Restart Services
        run: |
          echo "🔄 Restarting Open5GS services..."

          # Restart Control Plane services
          gcloud compute ssh open5gs-control --zone=${{ env.ZONE }} --tunnel-through-iap \
            --command "sudo systemctl restart open5gs-{nrfd,amfd,smfd,udmd,udrd,pcfd,ausfd,nssfd,bsfd}"

          # Restart User Plane
          gcloud compute ssh open5gs-userplane --zone=${{ env.ZONE }} --tunnel-through-iap \
            --command "sudo systemctl restart open5gs-upfd"

          echo "⏳ Waiting 30 seconds for services to stabilize..."
          sleep 30

          echo "✅ Services restarted"

      - name: Run Health Checks
        run: |
          echo "🔍 Running automated health checks..."

          # Check Control Plane services
          CONTROL_STATUS=$(gcloud compute ssh open5gs-control --zone=${{ env.ZONE }} --tunnel-through-iap \
            --command "systemctl is-active open5gs-{nrfd,smfd,amfd} 2>/dev/null | grep -c active")

          if [ "$CONTROL_STATUS" -lt 3 ]; then
            echo "❌ Control Plane health check failed!"
            exit 1
          fi

          # Check UPF
          UPF_STATUS=$(gcloud compute ssh open5gs-userplane --zone=${{ env.ZONE }} --tunnel-through-iap \
            --command "systemctl is-active open5gs-upfd")

          if [ "$UPF_STATUS" != "active" ]; then
            echo "❌ UPF health check failed!"
            exit 1
          fi

          # Check PFCP association
          sleep 5
          PFCP_CHECK=$(gcloud compute ssh open5gs-control --zone=${{ env.ZONE }} --tunnel-through-iap \
            --command "sudo journalctl -u open5gs-smfd -n 50 --no-pager | grep -c 'PFCP associated'")

          if [ "$PFCP_CHECK" -lt 1 ]; then
            echo "❌ SMF-UPF PFCP association check failed!"
            exit 1
          fi

          echo "✅ All health checks passed!"

      - name: Notify Success
        if: success()
        run: |
          echo "🎉 Configuration deployment completed successfully!"
          echo "📊 All services are healthy and operational."

      - name: Rollback on Failure
        if: failure()
        run: |
          echo "⚠️  Deployment failed! Rolling back to previous configuration..."

          # Find latest backup
          BACKUP=$(ls -t backups/*.tar.gz | head -1)

          if [ -f "$BACKUP" ]; then
            gcloud compute scp "$BACKUP" open5gs-control:/tmp/ --zone=${{ env.ZONE }} --tunnel-through-iap

            gcloud compute ssh open5gs-control --zone=${{ env.ZONE }} --tunnel-through-iap \
              --command "cd /tmp && sudo tar xzf $(basename $BACKUP) && sudo systemctl restart open5gs-*"

            echo "✅ Rollback completed"
          else
            echo "❌ No backup found for rollback!"
          fi
EOF

chmod +x .github/workflows/deploy-config.yml
```

### 4.3 Create Scheduled Health Check Workflow

Create `.github/workflows/scheduled-health-check.yml`:

```yaml
cat > .github/workflows/scheduled-health-check.yml << 'EOF'
name: Scheduled Network Health Check

on:
  schedule:
    # Run every 6 hours
    - cron: '0 */6 * * *'
  workflow_dispatch:

env:
  PROJECT_ID: telecom5g-prod2
  ZONE: us-central1-a

jobs:
  health-check:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup GCloud CLI
        uses: google-github-actions/setup-gcloud@v2
        with:
          service_account_key: ${{ secrets.GCP_SA_KEY }}
          project_id: ${{ env.PROJECT_ID }}

      - name: Run Health Checks
        run: bash scripts/test-network-health.sh

      - name: Upload Test Results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: health-check-results-${{ github.run_number }}
          path: test-results/*.txt

      - name: Create Issue on Failure
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: '🚨 Network Health Check Failed',
              body: 'Automated health check detected issues. Check workflow run for details.',
              labels: ['health-check', 'automated']
            })
EOF

chmod +x .github/workflows/scheduled-health-check.yml
```

### 4.4 Setup GitHub Secrets

**You need to create a GCP Service Account for GitHub Actions:**

```bash
# Create service account
gcloud iam service-accounts create github-actions-sa \
  --display-name="GitHub Actions Service Account"

# Grant compute admin role
gcloud projects add-iam-policy-binding telecom5g-prod2 \
  --member="serviceAccount:github-actions-sa@telecom5g-prod2.iam.gserviceaccount.com" \
  --role="roles/compute.admin"

# Create and download key
gcloud iam service-accounts keys create ~/github-actions-key.json \
  --iam-account=github-actions-sa@telecom5g-prod2.iam.gserviceaccount.com

# Display key (copy this for GitHub secrets)
cat ~/github-actions-key.json
```

**Add secret to GitHub:**

1. Go to your repository on GitHub
2. Settings → Secrets and variables → Actions
3. Click **New repository secret**
4. Name: `GCP_SA_KEY`
5. Value: Paste the entire JSON content from `github-actions-key.json`
6. Click **Add secret**

### 4.5 Commit CI/CD Pipeline

```bash
# Add workflows
git add .github/
git commit -m "Add CI/CD pipeline for configuration deployment and health monitoring"
git push
```

**✅ Checkpoint:** Your CI/CD pipeline is now active! Any config changes pushed to GitHub will be automatically deployed and tested.

---

## 🏗️ STEP 5: Create Configuration Management Scripts (25 minutes)

### 5.1 Create Config Update Helper

Create `scripts/update-config.sh`:

```bash
cat > scripts/update-config.sh << 'EOF'
#!/bin/bash
# Safe configuration update with validation and rollback

if [ $# -lt 2 ]; then
    echo "Usage: $0 <vm-name> <config-file>"
    echo "Example: $0 open5gs-control smf.yaml"
    exit 1
fi

VM_NAME=$1
CONFIG_FILE=$2
ZONE="us-central1-a"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "🔧 Updating configuration on ${VM_NAME}..."

# Step 1: Backup current config
echo "📦 Creating backup..."
gcloud compute ssh ${VM_NAME} --zone=${ZONE} --tunnel-through-iap \
  --command "sudo cp /etc/open5gs/${CONFIG_FILE} /etc/open5gs/${CONFIG_FILE}.backup-${TIMESTAMP}"

# Step 2: Validate new config syntax
echo "🔍 Validating YAML syntax..."
python3 -c "import yaml; yaml.safe_load(open('configs/open5gs/control/${CONFIG_FILE}'))" || {
    echo "❌ YAML syntax error! Aborting."
    exit 1
}

# Step 3: Upload new config
echo "📤 Uploading new configuration..."
gcloud compute scp configs/open5gs/control/${CONFIG_FILE} \
  ${VM_NAME}:/tmp/ --zone=${ZONE} --tunnel-through-iap

# Step 4: Apply config
echo "✅ Applying configuration..."
gcloud compute ssh ${VM_NAME} --zone=${ZONE} --tunnel-through-iap \
  --command "sudo cp /tmp/${CONFIG_FILE} /etc/open5gs/ && sudo chown root:root /etc/open5gs/${CONFIG_FILE}"

# Step 5: Restart relevant service
SERVICE_NAME=$(echo ${CONFIG_FILE} | sed 's/.yaml/d/')
echo "🔄 Restarting open5gs-${SERVICE_NAME}..."
gcloud compute ssh ${VM_NAME} --zone=${ZONE} --tunnel-through-iap \
  --command "sudo systemctl restart open5gs-${SERVICE_NAME}"

# Step 6: Verify service started
sleep 5
STATUS=$(gcloud compute ssh ${VM_NAME} --zone=${ZONE} --tunnel-through-iap \
  --command "systemctl is-active open5gs-${SERVICE_NAME}")

if [ "$STATUS" == "active" ]; then
    echo "✅ Configuration update successful!"
    echo "📋 Backup saved as: ${CONFIG_FILE}.backup-${TIMESTAMP}"
else
    echo "❌ Service failed to start! Rolling back..."
    gcloud compute ssh ${VM_NAME} --zone=${ZONE} --tunnel-through-iap \
      --command "sudo cp /etc/open5gs/${CONFIG_FILE}.backup-${TIMESTAMP} /etc/open5gs/${CONFIG_FILE} && sudo systemctl restart open5gs-${SERVICE_NAME}"
    echo "⚠️  Rollback completed. Check logs for errors."
    exit 1
fi

# Step 7: Commit to Git
echo "📝 Committing changes to Git..."
git add configs/open5gs/control/${CONFIG_FILE}
git commit -m "Update ${CONFIG_FILE} on ${VM_NAME}"
git push

echo "🎉 Configuration update completed and version controlled!"
EOF

chmod +x scripts/update-config.sh
```

### 5.2 Create Service Restart Helper

Create `scripts/restart-services.sh`:

```bash
cat > scripts/restart-services.sh << 'EOF'
#!/bin/bash
# Safe service restart with health validation

ZONE="us-central1-a"

echo "🔄 Restarting Open5GS services..."

# Restart User Plane first
echo "1️⃣ Restarting User Plane (UPF)..."
gcloud compute ssh open5gs-userplane --zone=${ZONE} --tunnel-through-iap \
  --command "sudo systemctl restart open5gs-upfd"

sleep 5

# Restart Control Plane services in correct order
echo "2️⃣ Restarting Control Plane services..."
gcloud compute ssh open5gs-control --zone=${ZONE} --tunnel-through-iap \
  --command "sudo systemctl restart open5gs-nrfd && sleep 2 && sudo systemctl restart open5gs-{amfd,smfd,udmd,udrd,pcfd,ausfd,nssfd,bsfd}"

echo "⏳ Waiting 30 seconds for services to stabilize..."
sleep 30

# Validate
echo "🔍 Running health validation..."
bash scripts/quick-status.sh

# Check PFCP association
echo "🔍 Checking SMF-UPF PFCP association..."
gcloud compute ssh open5gs-control --zone=${ZONE} --tunnel-through-iap \
  --command "sudo journalctl -u open5gs-smfd -n 20 --no-pager | grep 'PFCP associated'"

echo "✅ Service restart completed!"
EOF

chmod +x scripts/restart-services.sh
```

### 5.3 Commit Management Scripts

```bash
git add scripts/
git commit -m "Add configuration management and service control scripts"
git push
```

**✅ Checkpoint:** You now have safe, version-controlled configuration management!

---

## 🏗️ STEP 6: Documentation and Best Practices (15 minutes)

### 6.1 Create DevOps Runbook

Create `DEVOPS-RUNBOOK.md`:

````markdown
cat > DEVOPS-RUNBOOK.md << 'EOF'

# DevOps Runbook: Open5GS 5G Network Operations

## 🎯 Purpose

This runbook provides standard operating procedures for managing the Open5GS 5G network using DevOps practices.

---

## 📋 Daily Operations

### 1. Health Check

```bash
# Quick status check
bash scripts/quick-status.sh

# Full health test (10 tests)
bash scripts/test-network-health.sh
```
````

### 2. Configuration Changes

**Before making changes:**

1. Pull latest from Git: `git pull`
2. Create feature branch: `git checkout -b config-update-<description>`
3. Edit configs in `configs/open5gs/`
4. Validate syntax: `python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"`

**Deploy changes safely:**

```bash
# Use the safe update script
bash scripts/update-config.sh <vm-name> <config-file>

# Example: Update SMF config
bash scripts/update-config.sh open5gs-control smf.yaml
```

**Or push to GitHub (automated deployment):**

```bash
git add configs/
git commit -m "Update SMF timeout settings"
git push origin config-update-smf
# Create Pull Request on GitHub
# CI/CD pipeline will test and deploy after merge
```

### 3. Service Management

**Restart all services:**

```bash
bash scripts/restart-services.sh
```

**Restart specific service:**

```bash
gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
  --command "sudo systemctl restart open5gs-smfd"
```

**Check service logs:**

```bash
gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
  --command "sudo journalctl -u open5gs-smfd -n 100 --no-pager"
```

---

## 🚨 Incident Response

### Service Down

1. **Check service status:**

   ```bash
   bash scripts/quick-status.sh
   ```

2. **View recent logs:**

   ```bash
   gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
     --command "sudo journalctl -u open5gs-<service> -n 50 --no-pager"
   ```

3. **Restart service:**

   ```bash
   gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
     --command "sudo systemctl restart open5gs-<service>"
   ```

4. **If restart fails, rollback config:**

   ```bash
   # Find backup
   gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
     --command "ls -lt /etc/open5gs/*.backup-* | head -5"

   # Restore backup
   gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
     --command "sudo cp /etc/open5gs/smf.yaml.backup-<timestamp> /etc/open5gs/smf.yaml && sudo systemctl restart open5gs-smfd"
   ```

### Network Connectivity Issues

1. **Test UE connectivity:**

   ```bash
   gcloud compute ssh open5gs-ran --zone=us-central1-a --tunnel-through-iap \
     --command "ping -I uesimtun0 -c 4 8.8.8.8"
   ```

2. **Check PFCP association:**

   ```bash
   gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
     --command "sudo journalctl -u open5gs-smfd -n 50 --no-pager | grep PFCP"
   ```

3. **Verify UPF is running:**
   ```bash
   gcloud compute ssh open5gs-userplane --zone=us-central1-a --tunnel-through-iap \
     --command "sudo systemctl status open5gs-upfd"
   ```

---

## 📊 Monitoring

### Automated Checks

- GitHub Actions runs health checks every 6 hours
- Check workflow runs: https://github.com/YOUR-USERNAME/devops-5g-project/actions
- Failed checks create issues automatically

### Manual Monitoring

```bash
# Watch services in real-time
watch -n 5 bash scripts/quick-status.sh

# Monitor SMF logs
gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
  --command "sudo journalctl -u open5gs-smfd -f"
```

---

## 🔐 Security Best Practices

1. **Never commit credentials:**

   - Check `.gitignore` includes `*.key`, `*.pem`, `*credentials.json`
   - Use GitHub Secrets for CI/CD credentials

2. **Regular backups:**

   ```bash
   bash scripts/fetch-configs.sh
   git add configs/
   git commit -m "Backup: $(date +%Y-%m-%d)"
   git push
   ```

3. **Access control:**
   - Keep GitHub repository private
   - Use GCP IAM for VM access
   - Rotate service account keys quarterly

---

## 📚 Git Workflow

### Feature Branch Workflow

```bash
# Update main
git checkout main
git pull

# Create feature branch
git checkout -b feature/add-subscriber

# Make changes
# ... edit files ...

# Commit changes
git add .
git commit -m "Add new subscriber for testing"

# Push to GitHub
git push origin feature/add-subscriber

# Create Pull Request on GitHub
# CI/CD will validate changes
# Merge to main triggers deployment
```

### Hotfix Workflow

```bash
# For urgent fixes
git checkout main
git pull
git checkout -b hotfix/fix-smf-binding

# Make quick fix
# ... edit configs/open5gs/control/smf.yaml ...

# Deploy immediately using script
bash scripts/update-config.sh open5gs-control smf.yaml

# Commit and push
git add .
git commit -m "Hotfix: SMF binding issue"
git push origin hotfix/fix-smf-binding
```

---

## 📈 Performance Tuning

### Optimize MongoDB

```bash
gcloud compute ssh open5gs-database --zone=us-central1-a --tunnel-through-iap \
  --command "mongosh open5gs --eval 'db.subscribers.createIndex({imsi: 1})'"
```

### Check System Resources

```bash
# CPU usage
gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
  --command "top -bn1 | head -20"

# Memory usage
gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
  --command "free -h"

# Disk usage
gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
  --command "df -h"
```

---

## 📋 Daily Operations & Troubleshooting

### Quick Daily Health Checks

```bash
# Quick 30-second status check
bash scripts/quick-status.sh

# Full 2-minute comprehensive test (run daily)
bash scripts/test-network-health.sh
```

**Expected Output (Healthy Network):**

```
✅ MongoDB Service: PASS
✅ Control Plane (9 services): PASS
✅ UPF Service: PASS
✅ SMF-UPF PFCP Association: PASS
✅ NRF Service Discovery: PASS
✅ Subscriber Data: PASS
✅ Port 8805 (UPF only): PASS
✅ gNB Process Running: PASS
✅ UE Process Running: PASS
✅ Internet Connectivity: PASS

📊 TEST SUMMARY: 10/10 PASSED ✅
```

### Common Issues & Quick Fixes

#### Issue 1: Service Won't Start After Config Update

**Symptoms:** Service status is "failed" or "inactive"

**Quick Fix:**

```bash
# 1. Check logs for error
gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
  --command "sudo journalctl -u open5gs-smfd -n 50 --no-pager"

# 2. Rollback to last working config
git log --oneline configs/open5gs/control/smf.yaml | head -5
git checkout HEAD~1 -- configs/open5gs/control/smf.yaml

# 3. Redeploy
bash scripts/update-config.sh open5gs-control smf.yaml

# 4. Verify
bash scripts/quick-status.sh
```

#### Issue 2: Network Connectivity Test Fails

**Symptoms:** "Internet Connectivity: FAIL" in health test

**Quick Fix:**

```bash
# 1. Check UPF is running
gcloud compute ssh open5gs-userplane --zone=us-central1-a --tunnel-through-iap \
  --command "systemctl status open5gs-upfd"

# 2. Check SMF-UPF PFCP association
gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
  --command "sudo journalctl -u open5gs-smfd -n 50 --no-pager | grep PFCP"

# 3. Restart UE on RAN VM
gcloud compute ssh open5gs-ran --zone=us-central1-a --tunnel-through-iap \
  --command "sudo pkill nr-ue && cd ~/UERANSIM && sudo ./build/nr-ue -c config/open5gs-ue.yaml &"

# 4. Test again
bash scripts/test-network-health.sh
```

#### Issue 3: All Services Down After Restart

**Symptoms:** Multiple services failing, can't SSH to VMs

**Quick Fix:**

```bash
# 1. Check VMs are running
gcloud compute instances list --filter="name~open5gs"

# 2. Start stopped VMs
gcloud compute instances start open5gs-control open5gs-userplane --zone=us-central1-a

# 3. Wait 2 minutes, then restart services
bash scripts/restart-services.sh

# 4. Verify
bash scripts/test-network-health.sh
```

#### Issue 4: Config Change Broke Network

**Symptoms:** Health tests passed before change, failing after

**Quick Fix:**

```bash
# 1. See what changed
git log --oneline -5
git diff HEAD~1 HEAD

# 2. Rollback all recent changes
git checkout HEAD~1 -- configs/

# 3. Redeploy all configs
bash scripts/update-config.sh open5gs-control smf.yaml
bash scripts/update-config.sh open5gs-control amf.yaml
# ... repeat for changed files ...

# 4. Restart everything
bash scripts/restart-services.sh

# 5. Test
bash scripts/test-network-health.sh
```

### Using the Automation Scripts

#### Script 1: fetch-configs.sh

**Purpose:** Backup all configs from VMs to local Git repo

```bash
bash scripts/fetch-configs.sh
# Downloads: /etc/open5gs/*.yaml from all VMs
# Saves to: configs/open5gs/control/, configs/open5gs/userplane/
# Also exports MongoDB subscribers
```

**When to use:**

- Daily backup routine
- Before making changes
- After successful configuration updates
- Before system maintenance

#### Script 2: test-network-health.sh

**Purpose:** Run 10 comprehensive tests on entire 5G network

```bash
bash scripts/test-network-health.sh
# Takes ~2 minutes
# Generates report in: test-results/health-check-YYYYMMDD-HHMMSS.txt
# Exit code: 0 = all pass, 1 = some failed
```

**When to use:**

- Daily health verification
- After configuration changes
- After service restarts
- Before/after maintenance windows
- After VM reboots

#### Script 3: quick-status.sh

**Purpose:** Fast 30-second status overview

```bash
bash scripts/quick-status.sh
# Shows: MongoDB subscribers, active services, UPF status, UE connectivity
```

**When to use:**

- Quick troubleshooting
- Monitoring during development
- Before starting work session
- After suspected issues

#### Script 4: update-config.sh

**Purpose:** Safely update config with validation and auto-rollback

```bash
bash scripts/update-config.sh <vm-name> <config-file>

# Example:
bash scripts/update-config.sh open5gs-control smf.yaml

# What it does:
# 1. Creates backup on VM
# 2. Validates YAML syntax
# 3. Uploads new config
# 4. Restarts service
# 5. Tests if service started
# 6. If failed: auto-rollback
# 7. Commits change to Git
```

**When to use:**

- Any configuration change
- Testing new settings
- Applying config updates
- Safer than manual SSH editing

#### Script 5: restart-services.sh

**Purpose:** Restart all services in correct order with validation

```bash
bash scripts/restart-services.sh
# Order: UPF → NRF → All other control services
# Validates PFCP association after restart
```

**When to use:**

- After multiple config changes
- When services seem unresponsive
- After VM reboot
- Periodic maintenance restart

### Emergency Recovery Procedures

#### Scenario: Lost All Configs

```bash
# Your configs are safe in Git!
git log --oneline --all configs/

# Restore specific file
git checkout <commit-hash> -- configs/open5gs/control/smf.yaml

# Restore entire config directory
git checkout <commit-hash> -- configs/open5gs/

# Redeploy
bash scripts/update-config.sh open5gs-control smf.yaml
```

#### Scenario: Can't SSH to VMs

```bash
# Check VM status
gcloud compute instances list --filter="name~open5gs"

# Start if stopped
gcloud compute instances start <vm-name> --zone=us-central1-a

# Reset instance (last resort)
gcloud compute instances reset <vm-name> --zone=us-central1-a

# Wait 2 minutes, services auto-start
sleep 120
bash scripts/quick-status.sh
```

#### Scenario: Test Script Shows All Failures

```bash
# 1. Check basic connectivity
gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
  --command "echo 'Connected successfully'"

# 2. If connection fails, check IAP
gcloud compute firewall-rules list --filter="name~iap"

# 3. If connected, restart all services
bash scripts/restart-services.sh

# 4. If still failing, check MongoDB
gcloud compute ssh open5gs-database --zone=us-central1-a --tunnel-through-iap \
  --command "systemctl status mongod"

# 5. Restart MongoDB if needed
gcloud compute ssh open5gs-database --zone=us-central1-a --tunnel-through-iap \
  --command "sudo systemctl restart mongod"
```

### Monitoring Test Results Over Time

```bash
# View all test results
ls -lh test-results/

# Check latest test
cat test-results/health-check-*.txt | tail -50

# Count passing tests over time
grep -h "Success Rate:" test-results/*.txt

# Find when issue started
grep -l "FAIL" test-results/*.txt | sort
```

---

## 🎓 Learning Resources

- **Open5GS Documentation:** https://open5gs.org/open5gs/docs/
- **3GPP 5G Specs:** https://www.3gpp.org/specifications/79-specification-numbering
- **UERANSIM Guide:** https://github.com/aligungr/UERANSIM
- **Git Basics:** https://git-scm.com/doc
- **GitHub Actions:** https://docs.github.com/en/actions

---

## 📞 Support & References

- **GitHub Issues:** Create issue in your repository for tracking
- **GCP Console:** https://console.cloud.google.com/compute/instances?project=telecom5g-prod2
- **All scripts location:** `scripts/` directory in your project
- **Test results:** `test-results/` directory (timestamped logs)
- **Config backups:** `configs/open5gs/` directory (version controlled)

````

### 6.2 Update README with DevOps Section

Create `README-PHASE2.md`:

```markdown
cat > README-PHASE2.md << 'EOF'
# Phase 2 Complete: DevOps Layer Active ✅

## 🎉 What You've Accomplished

You've successfully added professional DevOps practices to your working 5G network:

### ✅ Version Control
- All configurations tracked in Git
- Full change history with commit messages
- Easy rollback to any previous state

### ✅ Automated Testing
- 10 comprehensive health tests
- Quick status checks
- Test results saved with timestamps

### ✅ CI/CD Pipeline
- Automatic deployment on config changes
- Validation before deployment
- Auto-rollback on failures
- Scheduled health checks every 6 hours

### ✅ Safe Operations
- Configuration backup before changes
- Service restart with validation
- Documented runbook procedures

---

## 📁 Repository Structure



---
````

devops-5g-project/
├── .github/workflows/ # CI/CD pipelines
│ ├── deploy-config.yml # Auto-deploy configs
│ └── scheduled-health-check.yml
├── configs/open5gs/ # Version-controlled configs
│ ├── control/ # Control Plane YAML files
│ ├── userplane/ # User Plane YAML files
│ └── database/ # MongoDB exports
├── scripts/ # Automation scripts
│ ├── fetch-configs.sh # Backup configs from VMs
│ ├── test-network-health.sh # 10-point health test
│ ├── quick-status.sh # Quick status check
│ ├── update-config.sh # Safe config updates
│ └── restart-services.sh # Service restart
├── test-results/ # Test outputs
├── DEVOPS-RUNBOOK.md # Operations guide
├── PHASE-1-VM-Infrastructure.md
├── PHASE-2-VM-DevOps.md
└── README.md

````

## 🚀 Daily Usage

### Health Check
```bash
bash scripts/quick-status.sh
````

### Full Testing

```bash
bash scripts/test-network-health.sh
```

### Update Configuration

```bash
# Edit file locally
nano configs/open5gs/control/smf.yaml

# Deploy safely
bash scripts/update-config.sh open5gs-control smf.yaml
```

### Backup Configs

```bash
bash scripts/fetch-configs.sh
git add configs/
git commit -m "Backup: $(date +%Y-%m-%d)"
git push
```

---

## 📊 CI/CD Pipeline Status

Check your pipeline: https://github.com/YOUR-USERNAME/devops-5g-project/actions

### Workflows Active:

- ✅ **Deploy Configuration:** Runs on every push to configs/
- ✅ **Scheduled Health Check:** Runs every 6 hours automatically

---

## 🎓 Next Steps

### Option 1: Move to Phase 3 (Recommended)

Add **Prometheus + Grafana monitoring** for real-time visibility.

- See: [PHASE-3-VM-Monitoring.md](PHASE-3-VM-Monitoring.md)

### Option 2: Test Your DevOps Setup

1. Make a small config change (e.g., logging level)
2. Push to GitHub
3. Watch CI/CD deploy automatically
4. Verify health checks pass

### Option 3: Extend Automation

- Add more tests to `test-network-health.sh`
- Create alert notifications (Slack, email)
- Add performance benchmarking

---

## 🎁 Key Benefits You Now Have

### 1. **Safe Changes**

No more manual SSH → edit → restart. Everything is automated with validation.

### 2. **Audit Trail**

Every change is tracked in Git with who, what, when, why.

### 3. **Quick Recovery**

If something breaks, rollback in seconds using Git history.

### 4. **Professional Operations**

Your 5G network now has enterprise-grade DevOps practices.

### 5. **Ready for Demo**

Show your DevOps knowledge: version control, CI/CD, automated testing.

---

## 📖 Documentation

- **Operations Guide:** [DEVOPS-RUNBOOK.md](DEVOPS-RUNBOOK.md)
- **Deployment Guide:** [PHASE-1-VM-Infrastructure.md](PHASE-1-VM-Infrastructure.md)
- **Critical Fixes:** [CRITICAL-FIXES-SUMMARY.md](CRITICAL-FIXES-SUMMARY.md)
- **Quick Reference:** [QUICK-REFERENCE.md](QUICK-REFERENCE.md)

---

## 🏆 Summary

**Before Phase 2:** Manual configuration changes, no testing, no version control
**After Phase 2:** Automated deployment, continuous testing, full change tracking

Your 5G network is now production-ready with professional DevOps practices! 🎉
EOF

````

### 6.3 Commit Documentation

```bash
git add DEVOPS-RUNBOOK.md README-PHASE2.md
git commit -m "Add DevOps runbook and Phase 2 summary documentation"
git push
````

---

## 🎉 OPTION A COMPLETE!

### ✅ What You've Achieved:

1. **Git Repository** ✅

   - All configurations version controlled
   - Full change history
   - Easy rollback capability

2. **Automated Testing** ✅

   - 10-point health check script
   - Quick status monitoring
   - Test result tracking

3. **CI/CD Pipeline** ✅

   - Automatic deployment on push
   - YAML validation
   - Health checks after deployment
   - Auto-rollback on failure
   - Scheduled monitoring every 6 hours

4. **Safe Operations** ✅

   - Configuration backup scripts
   - Safe update procedures
   - Service restart automation
   - Documented runbook

5. **Professional Documentation** ✅
   - Operations runbook
   - Incident response procedures
   - Git workflow guidelines

---

## 📊 Verify Your Setup

Run these commands to confirm everything is working:

```bash
# 1. Check Git repository
git status
git log --oneline -5

# 2. Test health check script
bash scripts/test-network-health.sh
# Expected: 10/10 tests passed ✅

# 3. Test quick status
bash scripts/quick-status.sh
# Expected: All services active ✅

# 4. Verify GitHub Actions
# Visit: https://github.com/YOUR-USERNAME/devops-5g-project/actions
# Expected: Workflows listed and ready ✅
```

---

## 🚀 Next Steps

### Recommended: Move to Phase 3 (Monitoring)

Now that you have DevOps practices in place, add **monitoring and visualization**:

- Real-time dashboards with Grafana
- Metrics collection with Prometheus
- UE tracking and throughput graphs
- Service health visualization

**Continue to:** [PHASE-3-VM-Monitoring.md](PHASE-3-VM-Monitoring.md)

---

## 💡 Pro Tips

### Test Your CI/CD Pipeline

Make a small change to test automated deployment:

```bash
# 1. Update a logging level
nano configs/open5gs/control/smf.yaml
# Change level: info → debug in logger section

# 2. Commit and push
git add configs/open5gs/control/smf.yaml
git commit -m "Test: Increase SMF logging verbosity for debugging"
git push

# 3. Watch GitHub Actions deploy it
# Visit: https://github.com/YOUR-USERNAME/devops-5g-project/actions

# 4. Verify deployment
gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
  --command "sudo cat /etc/open5gs/smf.yaml | grep 'level:'"
```

### Schedule Local Tests

Add to your crontab (Linux/Mac) or Task Scheduler (Windows):

```bash
# Run health check daily at 9 AM
0 9 * * * cd /path/to/devops-5g-project && bash scripts/test-network-health.sh
```

### Monitor Test Results

```bash
# View latest test results
cat test-results/health-check-*.txt | tail -50

# Count passing tests
grep -c "PASS" test-results/health-check-*.txt
```

---

## 🎓 Learning Outcomes

You now have hands-on experience with:

✅ **Git Version Control** - Branching, committing, pushing, history
✅ **CI/CD Pipelines** - GitHub Actions workflows, automated deployment
✅ **Infrastructure Testing** - Automated test suites, health checks
✅ **Configuration Management** - Safe updates, backups, rollbacks
✅ **DevOps Practices** - Runbooks, incident response, change management

These skills are directly transferable to real-world cloud infrastructure jobs!

---

**🎉 Congratulations! Your 5G network now has production-grade DevOps practices!**

Ready for Phase 3? → [PHASE-3-VM-Monitoring.md](PHASE-3-VM-Monitoring.md)

---

## 🏗️ STEP 1: Terraform Infrastructure as Code (60 minutes)

### 1.1 Create Project Structure

```bash
# Create directory structure
mkdir -p terraform ansible/inventory ansible/playbooks ansible/templates
mkdir -p scripts configs/open5gs configs/ueransim
mkdir -p .github/workflows

cd terraform
```

### 1.2 Create terraform/variables.tf

```bash
cat > variables.tf << 'EOF'
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "control_plane_ip" {
  description = "Control Plane VM private IP"
  type        = string
  default     = "10.10.0.2"
}

variable "user_plane_ip" {
  description = "User Plane VM private IP"
  type        = string
  default     = "10.11.0.7"
}

variable "db_ip" {
  description = "Database VM private IP"
  type        = string
  default     = "10.10.0.4"
}

variable "monitoring_ip" {
  description = "Monitoring VM private IP"
  type        = string
  default     = "10.10.0.50"
}

variable "ran_ip" {
  description = "RAN Simulator VM private IP"
  type        = string
  default     = "10.10.0.100"
}

variable "mcc" {
  description = "Mobile Country Code"
  type        = string
  default     = "999"
}

variable "mnc" {
  description = "Mobile Network Code"
  type        = string
  default     = "70"
}

variable "tac" {
  description = "Tracking Area Code"
  type        = number
  default     = 1
}
EOF
```

### 1.3 Create terraform/main.tf

````bash
cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ================================
#         VPC Network
# ================================
resource "google_compute_network" "open5gs_vpc" {
  name                    = "open5gs-vpc"
  auto_create_subnetworks = false
  description             = "Open5GS Core Network VPC"
}

# Control Plane Subnet
resource "google_compute_subnetwork" "control_subnet" {
  name          = "control-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.open5gs_vpc.id
  description   = "Control Plane and Signaling"
}

# User Plane Subnet
resource "google_compute_subnetwork" "data_subnet" {
  name          = "data-subnet"
  ip_cidr_range = "10.11.0.0/24"
  region        = var.region
  network       = google_compute_network.open5gs_vpc.id
  description   = "User Plane Data Traffic"
}

# ================================
#         Firewall Rules
# ================================
resource "google_compute_firewall" "allow_ssh" {
---

---

---

# OPTION B: Full Infrastructure as Code Rebuild (Advanced)

> **⚠️ WARNING:** This path requires destroying your working Phase 1 infrastructure and rebuilding everything from scratch using Terraform and Ansible.

**Only choose this if:**
- You need to deploy multiple 5G networks repeatedly
- You want to learn full Infrastructure-as-Code from scratch
- You're comfortable destroying your current working setup

**If you just want DevOps practices on your existing network, use Option A above!**

---

## 📋 Option B Overview

This path provides **complete automation** for repeatable deployments:

1. **Terraform Infrastructure as Code** - Automate all GCP resources
2. **Ansible Configuration Management** - Automate all service configs
3. **CI/CD with GitHub Actions** - Automate deployment pipeline
4. **UERANSIM Automation** - Automate RAN simulator setup

**Prerequisites:**
- Willingness to destroy Phase 1 infrastructure
- Terraform >= 1.5 installed locally
- Ansible >= 2.14 installed locally
- Time for full rebuild: 3-4 hours

---

## 🏗️ STEP 1: Terraform Infrastructure as Code (60 minutes)

### 1.1 Create Project Structure

```bash
# Create directory structure
mkdir -p terraform ansible/inventory ansible/playbooks ansible/templates
mkdir -p scripts configs/open5gs configs/ueransim
mkdir -p .github/workflows

cd terraform
````

### 1.2 Create terraform/variables.tf

```bash
cat > variables.tf << 'EOF'
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "control_plane_ip" {
  description = "Control Plane VM private IP"
  type        = string
  default     = "10.10.0.2"
}

variable "user_plane_ip" {
  description = "User Plane VM private IP"
  type        = string
  default     = "10.11.0.7"
}

variable "db_ip" {
  description = "Database VM private IP"
  type        = string
  default     = "10.10.0.4"
}

variable "monitoring_ip" {
  name    = "open5gs-allow-sctp"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "sctp"
    ports    = ["36412", "38412"]
  }
  source_ranges = ["10.10.0.0/24", "10.11.0.0/24"]
}

resource "google_compute_firewall" "allow_gtpu" {
  name    = "open5gs-allow-gtpu"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "udp"
    ports    = ["2152"]
  }
  source_ranges = ["10.10.0.0/24", "10.11.0.0/24"]
}

resource "google_compute_firewall" "allow_sbi" {
  name    = "open5gs-allow-sbi"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["7777"]
  }
  source_ranges = ["10.10.0.0/24"]
}

resource "google_compute_firewall" "allow_diameter" {
  name    = "open5gs-allow-diameter"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3868"]
  }
  allow {
    protocol = "sctp"
    ports    = ["3868"]
  }
  source_ranges = ["10.10.0.0/24"]
}

resource "google_compute_firewall" "allow_webui" {
  name    = "open5gs-allow-webui"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["9999"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_mongodb" {
  name    = "open5gs-allow-mongodb"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }
  source_ranges = ["10.10.0.0/24"]
}

resource "google_compute_firewall" "allow_monitoring" {
  name    = "open5gs-allow-monitoring"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["9090", "3000"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_internal" {
  name    = "open5gs-allow-internal"
  network = google_compute_network.open5gs_vpc.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["10.10.0.0/24", "10.11.0.0/24"]
}

# ================================
#         Compute Instances
# ================================

# Database VM
resource "google_compute_instance" "db" {
  name         = "open5gs-db"
  machine_type = "e2-small"
  zone         = var.zone
  tags         = ["database", "open5gs"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.control_subnet.name
    network_ip = var.db_ip
    # No external IP - internal only
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Control Plane VM
resource "google_compute_instance" "control" {
  name         = "open5gs-control"
  machine_type = "e2-standard-2"
  zone         = var.zone
  tags         = ["control-plane", "open5gs"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.control_subnet.name
    network_ip = var.control_plane_ip
    access_config {}  # Has external IP - bastion host
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# User Plane VM
resource "google_compute_instance" "userplane" {
  name         = "open5gs-userplane"
  machine_type = "e2-standard-2"
  zone         = var.zone
  tags         = ["user-plane", "open5gs"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.data_subnet.name
    network_ip = var.user_plane_ip
    # No external IP - internal only
  }

  can_ip_forward = true

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Monitoring VM
resource "google_compute_instance" "monitoring" {
  name         = "open5gs-monitoring"
  machine_type = "e2-small"
  zone         = var.zone
  tags         = ["monitoring", "open5gs"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.control_subnet.name
    network_ip = var.monitoring_ip
    access_config {}  # Has external IP - for WebUI/Grafana
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# RAN Simulator VM
resource "google_compute_instance" "ran" {
  name         = "open5gs-ran"
  machine_type = "e2-small"
  zone         = var.zone
  tags         = ["ran-simulator", "open5gs"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.control_subnet.name
    network_ip = var.ran_ip
    # No external IP - internal only
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}
EOF
```

### 1.4 Create terraform/outputs.tf

```bash
cat > outputs.tf << 'EOF'
output "db_external_ip" {
  value = google_compute_instance.db.network_interface[0].access_config[0].nat_ip
}

output "control_external_ip" {
  value = google_compute_instance.control.network_interface[0].access_config[0].nat_ip
}

output "userplane_external_ip" {
  value = google_compute_instance.userplane.network_interface[0].access_config[0].nat_ip
}

output "monitoring_external_ip" {
  value = google_compute_instance.monitoring.network_interface[0].access_config[0].nat_ip
}

output "ran_external_ip" {
  value = google_compute_instance.ran.network_interface[0].access_config[0].nat_ip
}

output "webui_url" {
  value = "http://${google_compute_instance.monitoring.network_interface[0].access_config[0].nat_ip}:9999"
}

output "grafana_url" {
  value = "http://${google_compute_instance.monitoring.network_interface[0].access_config[0].nat_ip}:3000"
}
EOF
```

### 1.5 Create terraform/terraform.tfvars

```bash
cat > terraform.tfvars << 'EOF'
project_id       = "telecom5g-prod2"  # Change to your project ID
region           = "us-central1"
zone             = "us-central1-a"
control_plane_ip = "10.10.0.2"
user_plane_ip    = "10.11.0.7"
db_ip            = "10.10.0.4"
monitoring_ip    = "10.10.0.50"
ran_ip           = "10.10.0.100"
mcc              = "999"
mnc              = "70"
tac              = 1
EOF
```

### 1.6 Initialize and Apply Terraform

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan -out=tfplan

# Apply (creates all resources)
terraform apply tfplan

# Get outputs
terraform output
```

---

## 🤖 STEP 2: Ansible Automation (90 minutes)

### 2.1 Create Ansible Inventory

```bash
cd ../ansible

cat > inventory/hosts.ini << 'EOF'
[database]
open5gs-db ansible_host=10.10.0.4

[control_plane]
open5gs-control ansible_host=10.10.0.2

[user_plane]
open5gs-userplane ansible_host=10.11.0.7

[monitoring]
open5gs-monitoring ansible_host=10.10.0.50

[ran_simulator]
open5gs-ran ansible_host=10.10.0.100

[open5gs:children]
database
control_plane
user_plane
monitoring
ran_simulator

[open5gs:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
db_ip=10.10.0.4
control_ip=10.10.0.2
userplane_ip=10.11.0.7
mcc=999
mnc=70
tac=1
EOF
```

### 2.2 Create ansible.cfg

```bash
cat > ansible.cfg << 'EOF'
[defaults]
inventory = inventory/hosts.ini
host_key_checking = False
remote_user = ubuntu
private_key_file = ~/.ssh/id_rsa
timeout = 30
roles_path = roles
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 86400

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
EOF
```

### 2.3 Create MongoDB Deployment Playbook

```bash
cat > playbooks/deploy_mongodb.yml << 'EOF'
---
- name: Deploy MongoDB
  hosts: database
  become: yes
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install prerequisites
      apt:
        name:
          - gnupg
          - curl
        state: present

    - name: Add MongoDB GPG key
      shell: |
        curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
        gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
      args:
        creates: /usr/share/keyrings/mongodb-server-8.0.gpg

    - name: Add MongoDB repository
      apt_repository:
        repo: "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse"
        state: present
        filename: mongodb-org-8.0

    - name: Install MongoDB
      apt:
        name: mongodb-org
        state: present
        update_cache: yes

    - name: Configure MongoDB for remote access
      lineinfile:
        path: /etc/mongod.conf
        regexp: '^  bindIp:'
        line: '  bindIp: 0.0.0.0'
        backup: yes

    - name: Start and enable MongoDB
      systemd:
        name: mongod
        state: started
        enabled: yes

    - name: Wait for MongoDB to be ready
      wait_for:
        port: 27017
        delay: 5
        timeout: 60

    - name: Verify MongoDB
      command: mongosh --eval "db.adminCommand('ping')"
      register: mongo_ping
      changed_when: false

    - name: Display MongoDB status
      debug:
        msg: "MongoDB is running: {{ mongo_ping.stdout }}"
EOF
```

### 2.4 Create 4G Core Deployment Playbook

```bash
cat > playbooks/deploy_4g.yml << 'EOF'
---
- name: Deploy 4G EPC
  hosts: control_plane
  become: yes
  vars:
    control_ip: "{{ hostvars['open5gs-control']['ansible_host'] }}"
    db_ip: "{{ hostvars['open5gs-db']['ansible_host'] }}"
    userplane_ip: "{{ hostvars['open5gs-userplane']['ansible_host'] }}"
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Add Open5GS PPA
      apt_repository:
        repo: ppa:open5gs/latest
        state: present

    - name: Install Open5GS
      apt:
        name: open5gs
        state: present
        update_cache: yes

    - name: Configure MME
      template:
        src: ../templates/mme.yaml.j2
        dest: /etc/open5gs/mme.yaml
        backup: yes
      notify: Restart MME

    - name: Configure HSS
      template:
        src: ../templates/hss.yaml.j2
        dest: /etc/open5gs/hss.yaml
        backup: yes
      notify: Restart HSS

    - name: Configure PCRF
      template:
        src: ../templates/pcrf.yaml.j2
        dest: /etc/open5gs/pcrf.yaml
        backup: yes
      notify: Restart PCRF

    - name: Configure SGW-C
      template:
        src: ../templates/sgwc.yaml.j2
        dest: /etc/open5gs/sgwc.yaml
        backup: yes
      notify: Restart SGWC

    - name: Configure SMF
      template:
        src: ../templates/smf.yaml.j2
        dest: /etc/open5gs/smf.yaml
        backup: yes
      notify: Restart SMF

    - name: Enable and start 4G services
      systemd:
        name: "{{ item }}"
        state: started
        enabled: yes
      loop:
        - open5gs-mmed
        - open5gs-hssd
        - open5gs-pcrfd
        - open5gs-sgwcd
        - open5gs-smfd

    - name: Wait for MME to be ready
      wait_for:
        port: 36412
        delay: 5
        timeout: 60

  handlers:
    - name: Restart MME
      systemd:
        name: open5gs-mmed
        state: restarted

    - name: Restart HSS
      systemd:
        name: open5gs-hssd
        state: restarted

    - name: Restart PCRF
      systemd:
        name: open5gs-pcrfd
        state: restarted

    - name: Restart SGWC
      systemd:
        name: open5gs-sgwcd
        state: restarted

    - name: Restart SMF
      systemd:
        name: open5gs-smfd
        state: restarted
EOF
```

### 2.5 Create 5G Core Deployment Playbook

```bash
cat > playbooks/deploy_5g.yml << 'EOF'
---
- name: Deploy 5G Core
  hosts: control_plane
  become: yes
  vars:
    control_ip: "{{ hostvars['open5gs-control']['ansible_host'] }}"
    db_ip: "{{ hostvars['open5gs-db']['ansible_host'] }}"
    userplane_ip: "{{ hostvars['open5gs-userplane']['ansible_host'] }}"
  tasks:
    - name: Configure NRF
      template:
        src: ../templates/nrf.yaml.j2
        dest: /etc/open5gs/nrf.yaml
        backup: yes
      notify: Restart NRF

    - name: Configure AMF
      template:
        src: ../templates/amf.yaml.j2
        dest: /etc/open5gs/amf.yaml
        backup: yes
      notify: Restart AMF

    - name: Configure UDM
      template:
        src: ../templates/udm.yaml.j2
        dest: /etc/open5gs/udm.yaml
        backup: yes
      notify: Restart UDM

    - name: Configure UDR
      template:
        src: ../templates/udr.yaml.j2
        dest: /etc/open5gs/udr.yaml
        backup: yes
      notify: Restart UDR

    - name: Configure PCF
      template:
        src: ../templates/pcf.yaml.j2
        dest: /etc/open5gs/pcf.yaml
        backup: yes
      notify: Restart PCF

    - name: Configure AUSF
      template:
        src: ../templates/ausf.yaml.j2
        dest: /etc/open5gs/ausf.yaml
        backup: yes
      notify: Restart AUSF

    - name: Configure NSSF
      template:
        src: ../templates/nssf.yaml.j2
        dest: /etc/open5gs/nssf.yaml
        backup: yes
      notify: Restart NSSF

    - name: Configure BSF
      template:
        src: ../templates/bsf.yaml.j2
        dest: /etc/open5gs/bsf.yaml
        backup: yes
      notify: Restart BSF

    - name: Start NRF first
      systemd:
        name: open5gs-nrfd
        state: started
        enabled: yes

    - name: Wait for NRF to be ready
      wait_for:
        port: 7777
        delay: 5
        timeout: 60

    - name: Enable and start 5G services
      systemd:
        name: "{{ item }}"
        state: started
        enabled: yes
      loop:
        - open5gs-amfd
        - open5gs-udmd
        - open5gs-udrd
        - open5gs-pcfd
        - open5gs-ausfd
        - open5gs-nssfd
        - open5gs-bsfd

    - name: Wait for AMF to be ready
      wait_for:
        port: 38412
        delay: 5
        timeout: 60

  handlers:
    - name: Restart NRF
      systemd:
        name: open5gs-nrfd
        state: restarted
    - name: Restart AMF
      systemd:
        name: open5gs-amfd
        state: restarted
    - name: Restart UDM
      systemd:
        name: open5gs-udmd
        state: restarted
    - name: Restart UDR
      systemd:
        name: open5gs-udrd
        state: restarted
    - name: Restart PCF
      systemd:
        name: open5gs-pcfd
        state: restarted
    - name: Restart AUSF
      systemd:
        name: open5gs-ausfd
        state: restarted
    - name: Restart NSSF
      systemd:
        name: open5gs-nssfd
        state: restarted
    - name: Restart BSF
      systemd:
        name: open5gs-bsfd
        state: restarted
EOF
```

### 2.6 Create User Plane Deployment Playbook

```bash
cat > playbooks/deploy_userplane.yml << 'EOF'
---
- name: Deploy User Plane
  hosts: user_plane
  become: yes
  vars:
    userplane_ip: "{{ hostvars['open5gs-userplane']['ansible_host'] }}"
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Add Open5GS PPA
      apt_repository:
        repo: ppa:open5gs/latest
        state: present

    - name: Install Open5GS
      apt:
        name: open5gs
        state: present
        update_cache: yes

    - name: Configure UPF
      template:
        src: ../templates/upf.yaml.j2
        dest: /etc/open5gs/upf.yaml
        backup: yes
      notify: Restart UPF

    - name: Configure SGW-U
      template:
        src: ../templates/sgwu.yaml.j2
        dest: /etc/open5gs/sgwu.yaml
        backup: yes
      notify: Restart SGWU

    - name: Enable IP forwarding
      sysctl:
        name: net.ipv4.ip_forward
        value: '1'
        sysctl_set: yes
        state: present
        reload: yes

    - name: Install iptables-persistent
      apt:
        name: iptables-persistent
        state: present

    - name: Configure NAT for 4G UE pool
      iptables:
        table: nat
        chain: POSTROUTING
        source: 10.45.0.0/16
        out_interface: "!ogstun"
        jump: MASQUERADE
      notify: Save iptables

    - name: Configure NAT for 5G UE pool
      iptables:
        table: nat
        chain: POSTROUTING
        source: 10.46.0.0/16
        out_interface: "!ogstun"
        jump: MASQUERADE
      notify: Save iptables

    - name: Allow ogstun input
      iptables:
        chain: INPUT
        in_interface: ogstun
        jump: ACCEPT
      notify: Save iptables

    - name: Allow ogstun forward in
      iptables:
        chain: FORWARD
        in_interface: ogstun
        jump: ACCEPT
      notify: Save iptables

    - name: Allow ogstun forward out
      iptables:
        chain: FORWARD
        out_interface: ogstun
        jump: ACCEPT
      notify: Save iptables

    - name: Enable and start user plane services
      systemd:
        name: "{{ item }}"
        state: started
        enabled: yes
      loop:
        - open5gs-upfd
        - open5gs-sgwud

    - name: Wait for UPF to be ready
      wait_for:
        port: 2152
        delay: 5
        timeout: 60

  handlers:
    - name: Restart UPF
      systemd:
        name: open5gs-upfd
        state: restarted

    - name: Restart SGWU
      systemd:
        name: open5gs-sgwud
        state: restarted

    - name: Save iptables
      command: netfilter-persistent save
EOF
```

### 2.7 Create AMF Template (Example)

```bash
cat > templates/amf.yaml.j2 << 'EOF'
amf:
  sbi:
    server:
      - address: {{ control_ip }}
        port: 7777
    client:
      scp:
        - uri: http://{{ control_ip }}:7777
      nrf:
        - uri: http://{{ control_ip }}:7777

  ngap:
    server:
      - address: {{ control_ip }}

  metrics:
    server:
      - address: {{ control_ip }}
        port: 9090

  guami:
    - plmn_id:
        mcc: {{ mcc }}
        mnc: {{ mnc }}
      amf_id:
        region: 2
        set: 1

  tai:
    - plmn_id:
        mcc: {{ mcc }}
        mnc: {{ mnc }}
      tac: {{ tac }}

  plmn_support:
    - plmn_id:
        mcc: {{ mcc }}
        mnc: {{ mnc }}
      s_nssai:
        - sst: 1
          sd: 000001
        - sst: 2
          sd: 000002

  security:
    integrity_order: [NIA2, NIA1, NIA0]
    ciphering_order: [NEA0, NEA1, NEA2]

  network_name:
    full: Open5GS

  amf_name: open5gs-amf0
EOF
```

### 2.8 Create UPF Template

```bash
cat > templates/upf.yaml.j2 << 'EOF'
upf:
  pfcp:
    server:
      - address: {{ userplane_ip }}

  gtpu:
    server:
      - address: {{ userplane_ip }}

  session:
    - subnet: 10.45.0.0/16
      gateway: 10.45.0.1
      dnn: internet
    - subnet: 10.46.0.0/16
      gateway: 10.46.0.1
      dnn: internet

  metrics:
    server:
      - address: {{ userplane_ip }}
        port: 9090
EOF
```

### 2.9 Create Master Deployment Playbook

```bash
cat > playbooks/deploy_all.yml << 'EOF'
---
- name: Deploy Complete Open5GS Infrastructure
  hosts: localhost
  gather_facts: no
  tasks:
    - name: Deploy MongoDB
      import_playbook: deploy_mongodb.yml

    - name: Deploy 4G Core
      import_playbook: deploy_4g.yml

    - name: Deploy 5G Core
      import_playbook: deploy_5g.yml

    - name: Deploy User Plane
      import_playbook: deploy_userplane.yml
EOF
```

### 2.10 Run Ansible Playbooks

```bash
# Test connectivity
ansible all -m ping

# Deploy step by step
ansible-playbook playbooks/deploy_mongodb.yml
ansible-playbook playbooks/deploy_4g.yml
ansible-playbook playbooks/deploy_5g.yml
ansible-playbook playbooks/deploy_userplane.yml

# Or deploy all at once
ansible-playbook playbooks/deploy_all.yml
```

---

## 🔄 STEP 3: CI/CD Pipeline with GitHub Actions (60 minutes)

### 3.1 Create Deploy Infrastructure Workflow

```bash
mkdir -p ../.github/workflows

cat > ../.github/workflows/deploy-infrastructure.yml << 'EOF'
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'
  workflow_dispatch:

env:
  TF_VERSION: '1.5.0'
  GCP_PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}

jobs:
  terraform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -out=tfplan -no-color
        continue-on-error: true

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan
EOF
```

### 3.2 Create Deploy Core Workflow

```bash
cat > ../.github/workflows/deploy-core.yml << 'EOF'
name: Deploy Open5GS Core

on:
  workflow_dispatch:
    inputs:
      component:
        description: 'Component to deploy'
        required: true
        type: choice
        options:
          - all
          - mongodb
          - 4g-core
          - 5g-core
          - userplane

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install Ansible
        run: |
          pip install ansible
          ansible --version

      - name: Setup SSH Key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Configure SSH ProxyJump
        run: |
          gcloud compute config-ssh --project=${{ secrets.GCP_PROJECT_ID }}

      - name: Deploy Component
        working-directory: ansible
        run: |
          case "${{ github.event.inputs.component }}" in
            all)
              ansible-playbook playbooks/deploy_all.yml
              ;;
            mongodb)
              ansible-playbook playbooks/deploy_mongodb.yml
              ;;
            4g-core)
              ansible-playbook playbooks/deploy_4g.yml
              ;;
            5g-core)
              ansible-playbook playbooks/deploy_5g.yml
              ;;
            userplane)
              ansible-playbook playbooks/deploy_userplane.yml
              ;;
          esac
EOF
```

### 3.3 Create Health Check Workflow

```bash
cat > ../.github/workflows/health-check.yml << 'EOF'
name: Health Check

on:
  schedule:
    - cron: '*/30 * * * *'  # Every 30 minutes
  workflow_dispatch:

jobs:
  health-check:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Setup gcloud
        uses: google-github-actions/setup-gcloud@v2
        with:
          project_id: ${{ secrets.GCP_PROJECT_ID }}

      - name: Check VMs Status
        run: |
          echo "=== VM Status ==="
          gcloud compute instances list --filter="name~open5gs" --format="table(name,status,networkInterfaces[0].networkIP)"

      - name: Check MME (4G)
        run: |
          echo "=== Checking MME ==="
          gcloud compute ssh open5gs-control --zone=us-central1-a --command="sudo ss -tlnp | grep 36412" || echo "MME not responding"

      - name: Check AMF (5G)
        run: |
          echo "=== Checking AMF ==="
          gcloud compute ssh open5gs-control --zone=us-central1-a --command="sudo ss -tlnp | grep 38412" || echo "AMF not responding"

      - name: Check UPF
        run: |
          echo "=== Checking UPF ==="
          gcloud compute ssh open5gs-userplane --zone=us-central1-a --tunnel-through-iap --command="sudo ss -ulnp | grep 2152" || echo "UPF not responding"

      - name: Check WebUI
        run: |
          echo "=== Checking WebUI ==="
          WEBUI_IP=$(gcloud compute instances describe open5gs-monitoring --zone=us-central1-a --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
          curl -s -o /dev/null -w "%{http_code}" http://${WEBUI_IP}:9999 || echo "WebUI not accessible"
EOF
```

---

## 📡 STEP 4: UERANSIM Deployment (30 minutes)

### 4.1 SSH into RAN Simulator VM

```bash
# RAN VM has no external IP - use IAP tunneling
gcloud compute ssh open5gs-ran --zone=$ZONE --tunnel-through-iap
```

### 4.2 Install UERANSIM

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install build dependencies
sudo apt install -y make g++ libsctp-dev lksctp-tools iproute2

# Install cmake
sudo snap install cmake --classic

# Clone UERANSIM
cd ~
git clone https://github.com/aligungr/UERANSIM
cd UERANSIM

# Build
make

echo "✅ UERANSIM built successfully"
```

### 4.3 Configure 5G gNB

```bash
cat > config/open5gs-gnb.yaml << 'EOF'
mcc: '999'
mnc: '70'

nci: '0x000000010'
idLength: 32
tac: 1

linkIp: 10.10.0.100   # RAN VM IP
ngapIp: 10.10.0.100   # RAN VM IP
gtpIp: 10.10.0.100    # RAN VM IP

amfConfigs:
  - address: 10.10.0.2  # Control Plane VM IP
    port: 38412

slices:
  - sst: 1
    sd: 0x000001
  - sst: 2
    sd: 0x000002

ignoreStreamIds: true
EOF
```

### 4.4 Configure 5G UE

```bash
cat > config/open5gs-ue.yaml << 'EOF'
supi: 'imsi-999700000000002'
mcc: '999'
mnc: '70'

key: '465B5CE8B199B49FAA5F0A2EE238A6BC'
op: 'E8ED289DEBA952E4283B54E88E6183CA'
opType: 'OPC'
amf: '8000'

imei: '356938035643803'
imeiSv: '4370816125816151'

gnbSearchList:
  - 10.10.0.100

uacAic:
  mps: false
  mcs: false

uacAcc:
  normalClass: 0
  class11: false
  class12: false
  class13: false
  class14: false
  class15: false

sessions:
  - type: 'IPv4'
    apn: 'internet'
    slice:
      sst: 1
      sd: 0x000001

configured-nssai:
  - sst: 1
    sd: 0x000001

default-nssai:
  - sst: 1
    sd: 0x000001
EOF
```

### 4.5 Test 5G Connection

```bash
# Terminal 1: Start gNB
cd ~/UERANSIM
./build/nr-gnb -c config/open5gs-gnb.yaml

# Terminal 2: Start UE
cd ~/UERANSIM
sudo ./build/nr-ue -c config/open5gs-ue.yaml

# Terminal 3: Test connectivity
ping -I uesimtun0 8.8.8.8
```

### 4.6 Exit RAN VM

```bash
exit
```

---

## ✅ Phase 2 Validation Checklist

```
Terraform:
[✓] All resources defined in .tf files
[✓] terraform init succeeds
[✓] terraform validate passes
[✓] terraform plan shows expected resources
[✓] terraform apply creates infrastructure

Ansible:
[✓] Inventory file with all hosts
[✓] ansible all -m ping succeeds
[✓] MongoDB playbook deploys successfully
[✓] 4G Core playbook deploys successfully
[✓] 5G Core playbook deploys successfully
[✓] User Plane playbook deploys successfully

CI/CD:
[✓] GitHub workflows created
[✓] GCP secrets configured in GitHub
[✓] Infrastructure workflow runs
[✓] Core deployment workflow runs
[✓] Health check workflow scheduled

UERANSIM:
[✓] UERANSIM built successfully
[✓] gNB configuration created
[✓] UE configuration created
[✓] gNB connects to AMF
[✓] UE registers successfully
[✓] Data plane connectivity works
```

---

## 🛠️ Troubleshooting

### Ansible Connection Issues

```bash
# Test SSH connectivity
ssh -i ~/.ssh/id_rsa ubuntu@<EXTERNAL_IP>

# Test Ansible ping
ansible all -m ping -vvv

# Common fix: add host keys
ssh-keyscan <EXTERNAL_IP> >> ~/.ssh/known_hosts
```

### UERANSIM gNB Not Connecting

```bash
# Check AMF is listening
gcloud compute ssh open5gs-control --command="sudo ss -tlnp | grep 38412"

# Check firewall rules
gcloud compute firewall-rules list --filter="name~open5gs"

# Check SCTP connectivity from RAN
sudo apt install -y sctp-tools
sctp_test -H 10.10.0.100 -P 38412 -h 10.10.0.2 -p 38412 -s
```

### CI/CD Workflow Failures

```bash
# Check GitHub Actions logs
# Go to: Repository > Actions > Select workflow > View logs

# Verify secrets are set
# Go to: Repository > Settings > Secrets and variables > Actions

# Required secrets:
# - GCP_PROJECT_ID
# - GCP_SA_KEY (JSON key for service account)
# - SSH_PRIVATE_KEY
```

---

## 🎯 What's Next?

**Phase 2 Complete!** ✅

You now have:

- ✅ Terraform IaC for infrastructure
- ✅ Ansible automation for configuration
- ✅ CI/CD pipelines for deployment
- ✅ UERANSIM for RAN simulation

**Proceed to:** [PHASE-3-VM-Monitoring.md](PHASE-3-VM-Monitoring.md)

In Phase 3, you will:

- Set up Prometheus and Grafana monitoring
- Configure 5G network slicing (eMBB/URLLC)
- Run performance benchmarks
- Generate QoS/QoE reports

---

**Time Spent:** 3-4 hours | **Status:** Automation Complete
