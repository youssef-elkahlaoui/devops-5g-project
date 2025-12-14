# PHASE 3: Monitoring, Slicing & Benchmarking (VM-Based)

**⏱️ Duration: 2-4 Hours | 🎯 Goal: Monitoring, 5G Slicing, QoS/QoE Analysis**

---

> ⚠️ **NOTE FOR ACADEMIC PROJECTS:** This phase is for advanced users who want monitoring and slicing. If you just need to demonstrate 4G/5G connectivity, **Phase 1 alone is sufficient!** You can skip directly to STEP 3 (benchmarking) after Phase 1 for basic testing.

---

## 📋 Phase 3 Overview

In this phase, you will:

1. Deploy Prometheus and Grafana for monitoring
2. Configure 5G Network Slicing (eMBB & URLLC)
3. Create test subscribers for each slice
4. Run comprehensive benchmarks
5. Compare 4G vs 5G performance
6. Generate QoS/QoE analysis reports

**Result:** Full visibility into network performance with slice-based QoS differentiation

---

## ✅ Prerequisites

- ✅ **Phase 1 completed** - Core network running with UERANSIM installed
- ✅ **Phase 2 (OPTIONAL)** - DevOps automation (recommended but not required)
- ✅ **Test subscriber added** via WebUI (imsi-999700000000002)
- ✅ **SSH access** to monitoring VM

**Verify prerequisites:**

```bash
# Check 5G core is running
gcloud compute ssh open5gs-control --zone=us-central1-a --tunnel-through-iap \
  --command "systemctl is-active open5gs-amfd open5gs-smfd"

# Check UERANSIM is installed (from Phase 1 BONUS section)
gcloud compute ssh open5gs-ran --zone=us-central1-a --tunnel-through-iap \
  --command "ls ~/UERANSIM/build/nr-gnb"

# Expected: Both commands show 'active' and UERANSIM binary exists
```

> **Note:** UERANSIM should be installed from Phase 1 BONUS section. If you skipped it, go back to [PHASE-1-VM-Infrastructure.md](PHASE-1-VM-Infrastructure.md) and complete the BONUS section first.

---

## 📊 STEP 1: Prometheus & Grafana Setup (45 minutes)

### 1.1 SSH into Monitoring VM

```bash
export PROJECT_ID="telecom5g-prod2"  # Change to your project ID
export ZONE="us-central1-a"

gcloud compute ssh open5gs-monitoring --zone=$ZONE
```

### 1.2 Install Prometheus

```bash
# Create prometheus user
sudo useradd --no-create-home --shell /bin/false prometheus

# Download Prometheus
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz
tar xvfz prometheus-2.48.0.linux-amd64.tar.gz
cd prometheus-2.48.0.linux-amd64

# Install binaries
sudo cp prometheus promtool /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

# Create directories
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Copy console files
sudo cp -r consoles console_libraries /etc/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus
```

### 1.3 Configure Prometheus for Open5GS

```bash
sudo tee /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    environment: 'production'
    deployment: 'open5gs-vm'

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files:
  - /etc/prometheus/rules/*.yml

scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Open5GS Control Plane Metrics
  - job_name: 'open5gs-control'
    static_configs:
      - targets:
          - '10.10.0.2:9090'  # AMF metrics
        labels:
          component: 'amf'
          plane: 'control'
      - targets:
          - '10.10.0.2:9091'  # SMF metrics
        labels:
          component: 'smf'
          plane: 'control'
      - targets:
          - '10.10.0.2:9092'  # PCF metrics
        labels:
          component: 'pcf'
          plane: 'control'
      - targets:
          - '10.10.0.2:9093'  # NRF metrics
        labels:
          component: 'nrf'
          plane: 'control'

  # Open5GS User Plane Metrics
  - job_name: 'open5gs-userplane'
    static_configs:
      - targets:
          - '10.11.0.7:9090'  # UPF metrics
        labels:
          component: 'upf'
          plane: 'user'
      - targets:
          - '10.11.0.7:9091'  # SMF metrics
        labels:
          component: 'sgwu'
          plane: 'user'

  # Node Exporter (System Metrics)
  - job_name: 'node-exporter'
    static_configs:
      - targets:
          - '10.10.0.2:9100'
          - '10.11.0.7:9100'
          - '10.10.0.4:9100'
          - '10.10.0.100:9100'
          - '10.10.0.50:9100'
        labels:
          exporter: 'node'

  # MongoDB Metrics
  - job_name: 'mongodb'
    static_configs:
      - targets: ['10.10.0.4:9216']
        labels:
          component: 'mongodb'
EOF

sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml
```

### 1.4 Create Prometheus Alert Rules

```bash
sudo mkdir -p /etc/prometheus/rules

sudo tee /etc/prometheus/rules/open5gs.yml << 'EOF'
groups:
  - name: open5gs-alerts
    rules:
      - alert: AMFDown
        expr: up{job="open5gs-control",component="amf"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "AMF is down"
          description: "AMF has been down for more than 1 minute"

      - alert: UPFDown
        expr: up{job="open5gs-userplane",component="upf"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "UPF is down"
          description: "UPF has been down for more than 1 minute"

      - alert: HighLatency
        expr: histogram_quantile(0.99, rate(open5gs_upf_session_latency_bucket[5m])) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency detected"
          description: "99th percentile latency is above 100ms"

      - alert: HighCPUUsage
        expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage"
          description: "CPU usage is above 80%"
EOF

sudo chown -R prometheus:prometheus /etc/prometheus/rules
```

### 1.5 Create Prometheus Service

```bash
sudo tee /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/ \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --web.enable-lifecycle
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

# Verify
sudo systemctl status prometheus
```

### 1.6 Install Grafana

```bash
# Add Grafana repository
sudo apt-get install -y apt-transport-https software-properties-common
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

# Install Grafana
sudo apt-get update
sudo apt-get install -y grafana

# Start Grafana
sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

echo "✅ Grafana installed and running on port 3000"
```

### 1.7 Configure Grafana Data Source

```bash
# Wait for Grafana to start
sleep 10

# Add Prometheus data source
curl -X POST -H "Content-Type: application/json" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://localhost:9090",
    "access": "proxy",
    "isDefault": true
  }' \
  http://admin:admin@localhost:3000/api/datasources

echo "✅ Prometheus data source added to Grafana"
```

### 1.8 Install Node Exporter on All VMs

```bash
# Exit monitoring VM
exit

# Install on all VMs
for VM in open5gs-control open5gs-userplane open5gs-db open5gs-ran open5gs-monitoring; do
  echo "Installing Node Exporter on $VM..."
  gcloud compute ssh $VM --zone=$ZONE --command='
    cd /tmp
    wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
    tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
    sudo cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/

    sudo useradd --no-create-home --shell /bin/false node_exporter || true

    sudo tee /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable node_exporter
    sudo systemctl start node_exporter
  '
done

echo "✅ Node Exporter installed on all VMs"
```

---

## 🔀 STEP 2: 5G Network Slicing Configuration (45 minutes)

> ⚠️ **OPTIONAL:** Network slicing is an advanced feature. For academic demos, you can skip this step and use the basic eMBB slice (SST=1) that's already configured by default.

### 2.1 Understanding Network Slices

| Slice Type | SST | SD     | Description                | Use Case                         |
| ---------- | --- | ------ | -------------------------- | -------------------------------- |
| eMBB       | 1   | 000001 | Enhanced Mobile Broadband  | Video streaming, large downloads |
| URLLC      | 2   | 000002 | Ultra-Reliable Low Latency | Industrial IoT, remote surgery   |

### 2.2 Configure Slices in AMF

```bash
gcloud compute ssh open5gs-control --zone=$ZONE

sudo tee /etc/open5gs/amf.yaml << 'EOF'
amf:
  sbi:
    server:
      - address: 10.10.0.2
        port: 7777
    client:
      nrf:
        - uri: http://10.10.0.2:7777

  ngap:
    server:
      - address: 10.10.0.2

  metrics:
    server:
      - address: 10.10.0.2
        port: 9090

  guami:
    - plmn_id:
        mcc: 999
        mnc: 70
      amf_id:
        region: 2
        set: 1

  tai:
    - plmn_id:
        mcc: 999
        mnc: 70
      tac: 1

  plmn_support:
    - plmn_id:
        mcc: 999
        mnc: 70
      s_nssai:
        # Slice 1: eMBB (Enhanced Mobile Broadband)
        - sst: 1
          sd: 000001
        # Slice 2: URLLC (Ultra-Reliable Low Latency)
        - sst: 2
          sd: 000002

  security:
    integrity_order: [NIA2, NIA1, NIA0]
    ciphering_order: [NEA0, NEA1, NEA2]

  network_name:
    full: Open5GS Lab

  amf_name: open5gs-amf0
EOF

sudo systemctl restart open5gs-amfd
```

### 2.3 Configure Slices in NSSF

```bash
sudo tee /etc/open5gs/nssf.yaml << 'EOF'
nssf:
  sbi:
    server:
      - address: 10.10.0.2
        port: 7777
    client:
      nrf:
        - uri: http://10.10.0.2:7777
      scp:
        - uri: http://10.10.0.2:7777

  nsi:
    # Slice 1: eMBB - Enhanced Mobile Broadband
    - addr: 10.10.0.2
      port: 7777
      s_nssai:
        sst: 1
        sd: 000001

    # Slice 2: URLLC - Ultra-Reliable Low Latency
    - addr: 10.10.0.2
      port: 7777
      s_nssai:
        sst: 2
        sd: 000002
EOF

sudo systemctl restart open5gs-nssfd
```

### 2.4 Configure Slice-specific SMF Settings

```bash
sudo tee /etc/open5gs/smf.yaml << 'EOF'
smf:
  sbi:
    server:
      - address: 10.10.0.2
        port: 7777
    client:
      nrf:
        - uri: http://10.10.0.2:7777

  pfcp:
    server:
      - address: 10.10.0.2
    client:
      upf:
        - address: 10.11.0.7

  gtpc:
    server:
      - address: 10.10.0.2

  gtpu:
    server:
      - address: 10.10.0.2

  metrics:
    server:
      - address: 10.10.0.2
        port: 9091

  session:
    # eMBB Slice - High bandwidth, normal latency
    - subnet: 10.46.0.0/16
      gateway: 10.46.0.1
      dnn: internet
      s_nssai:
        sst: 1
        sd: 000001

    # URLLC Slice - Lower bandwidth, ultra-low latency
    - subnet: 10.47.0.0/16
      gateway: 10.47.0.1
      dnn: iot
      s_nssai:
        sst: 2
        sd: 000002

  dns:
    - 8.8.8.8
    - 8.8.4.4

  mtu: 1400
  ctf:
    enabled: auto
EOF

sudo systemctl restart open5gs-smfd
```

### 2.5 Configure UPF for Multiple Slices

```bash
# Exit control plane
exit

# SSH to user plane
gcloud compute ssh open5gs-userplane --zone=$ZONE

sudo tee /etc/open5gs/upf.yaml << 'EOF'
upf:
  pfcp:
    server:
      - address: 10.11.0.7

  gtpu:
    server:
      - address: 10.11.0.7

  session:
    # eMBB Slice Pool
    - subnet: 10.46.0.0/16
      gateway: 10.46.0.1
      dnn: internet

    # URLLC Slice Pool
    - subnet: 10.47.0.0/16
      gateway: 10.47.0.1
      dnn: iot

  metrics:
    server:
      - address: 10.11.0.7
        port: 9090
EOF

# Add NAT for new slice
sudo iptables -t nat -A POSTROUTING -s 10.47.0.0/16 ! -o ogstun -j MASQUERADE
sudo netfilter-persistent save

sudo systemctl restart open5gs-upfd

exit
```

### 2.6 Create Subscribers for Each Slice

Access WebUI at `http://<MONITORING_IP>:9999` and add subscribers:

**eMBB Subscriber (IMSI: 999700000000001)**

```
IMSI: 999700000000001
K: 465B5CE8B199B49FAA5F0A2EE238A6BC
OPC: E8ED289DEBA952E4283B54E88E6183CA
AMF: 8000
APN: internet
S-NSSAI: SST=1, SD=000001
```

**URLLC Subscriber (IMSI: 999700000000002)**

```
IMSI: 999700000000002
K: 465B5CE8B199B49FAA5F0A2EE238A6BC
OPC: E8ED289DEBA952E4283B54E88E6183CA
AMF: 8000
APN: iot
S-NSSAI: SST=2, SD=000002
```

---

## 📈 STEP 3: UERANSIM Benchmarking (45 minutes)

### 3.1 Configure UERANSIM for Multiple UEs

```bash
gcloud compute ssh open5gs-ran --zone=$ZONE

cd ~/UERANSIM
```

### 3.2 Create eMBB UE Configuration

```bash
cat > config/embb-ue.yaml << 'EOF'
supi: 'imsi-999700000000001'
mcc: '999'
mnc: '70'

key: '465B5CE8B199B49FAA5F0A2EE238A6BC'
op: 'E8ED289DEBA952E4283B54E88E6183CA'
opType: 'OPC'
amf: '8000'

gnbSearchList:
  - 10.10.0.100

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

### 3.3 Create URLLC UE Configuration

```bash
cat > config/urllc-ue.yaml << 'EOF'
supi: 'imsi-999700000000002'
mcc: '999'
mnc: '70'

key: '465B5CE8B199B49FAA5F0A2EE238A6BC'
op: 'E8ED289DEBA952E4283B54E88E6183CA'
opType: 'OPC'
amf: '8000'

gnbSearchList:
  - 10.10.0.100

sessions:
  - type: 'IPv4'
    apn: 'iot'
    slice:
      sst: 2
      sd: 0x000002

configured-nssai:
  - sst: 2
    sd: 0x000002

default-nssai:
  - sst: 2
    sd: 0x000002
EOF
```

### 3.4 Create Benchmark Script

```bash
cat > benchmark.sh << 'EOF'
#!/bin/bash
# Open5GS Benchmark Script
# Tests latency, throughput, and jitter for different slices

RESULTS_DIR="results/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "============================================"
echo "Open5GS Benchmark Suite"
echo "Date: $(date)"
echo "============================================"

# Function: Latency Test
test_latency() {
    local interface=$1
    local target=$2
    local slice=$3
    echo "Testing latency on $slice slice..."
    ping -I $interface -c 100 $target > "$RESULTS_DIR/${slice}_latency.txt"

    # Extract statistics
    avg=$(tail -1 "$RESULTS_DIR/${slice}_latency.txt" | awk -F'/' '{print $5}')
    echo "  Average latency ($slice): ${avg}ms"
}

# Function: Throughput Test (Download)
test_throughput_download() {
    local interface=$1
    local slice=$2
    echo "Testing download throughput on $slice slice..."
    curl --interface $interface -o /dev/null -w '%{speed_download}' \
         http://speedtest.tele2.net/10MB.zip 2>/dev/null > "$RESULTS_DIR/${slice}_download.txt"

    speed=$(cat "$RESULTS_DIR/${slice}_download.txt")
    speed_mbps=$(echo "scale=2; $speed / 1000000 * 8" | bc)
    echo "  Download speed ($slice): ${speed_mbps} Mbps"
}

# Function: Throughput Test (Upload)
test_throughput_upload() {
    local interface=$1
    local slice=$2
    echo "Testing upload throughput on $slice slice..."
    dd if=/dev/zero bs=1M count=10 2>/dev/null | \
        curl --interface $interface -X POST -d @- \
        -w '%{speed_upload}' http://speedtest.tele2.net/upload.php 2>/dev/null \
        > "$RESULTS_DIR/${slice}_upload.txt"

    speed=$(cat "$RESULTS_DIR/${slice}_upload.txt")
    speed_mbps=$(echo "scale=2; $speed / 1000000 * 8" | bc)
    echo "  Upload speed ($slice): ${speed_mbps} Mbps"
}

# Function: Jitter Test
test_jitter() {
    local interface=$1
    local target=$2
    local slice=$3
    echo "Testing jitter on $slice slice..."

    # Collect ping times
    ping -I $interface -c 50 $target | grep "time=" | \
        awk -F'time=' '{print $2}' | awk '{print $1}' > "$RESULTS_DIR/${slice}_pings.txt"

    # Calculate jitter (average deviation)
    awk '{
        sum += $1;
        sq_sum += $1*$1;
        count++
    } END {
        mean = sum/count;
        variance = sq_sum/count - mean*mean;
        jitter = sqrt(variance);
        printf "%.2f", jitter
    }' "$RESULTS_DIR/${slice}_pings.txt" > "$RESULTS_DIR/${slice}_jitter.txt"

    jitter=$(cat "$RESULTS_DIR/${slice}_jitter.txt")
    echo "  Jitter ($slice): ${jitter}ms"
}

# Function: Packet Loss Test
test_packet_loss() {
    local interface=$1
    local target=$2
    local slice=$3
    echo "Testing packet loss on $slice slice..."

    loss=$(ping -I $interface -c 100 -q $target | grep "packet loss" | \
           awk -F',' '{print $3}' | awk '{print $1}')
    echo "$loss" > "$RESULTS_DIR/${slice}_packet_loss.txt"
    echo "  Packet loss ($slice): $loss"
}

# Run benchmarks
echo ""
echo "=== eMBB Slice Tests ==="
if ip link show uesimtun0 &>/dev/null; then
    test_latency uesimtun0 8.8.8.8 "embb"
    test_jitter uesimtun0 8.8.8.8 "embb"
    test_packet_loss uesimtun0 8.8.8.8 "embb"
    test_throughput_download uesimtun0 "embb"
else
    echo "uesimtun0 not available"
fi

echo ""
echo "=== URLLC Slice Tests ==="
if ip link show uesimtun1 &>/dev/null; then
    test_latency uesimtun1 8.8.8.8 "urllc"
    test_jitter uesimtun1 8.8.8.8 "urllc"
    test_packet_loss uesimtun1 8.8.8.8 "urllc"
    test_throughput_download uesimtun1 "urllc"
else
    echo "uesimtun1 not available"
fi

# Generate summary
echo ""
echo "=== Benchmark Summary ==="
echo "Results saved to: $RESULTS_DIR"

cat > "$RESULTS_DIR/summary.json" << EOFSUM
{
  "timestamp": "$(date -Iseconds)",
  "slices": {
    "embb": {
      "latency_avg_ms": $(cat "$RESULTS_DIR/embb_latency.txt" 2>/dev/null | tail -1 | awk -F'/' '{print $5}' || echo "null"),
      "jitter_ms": $(cat "$RESULTS_DIR/embb_jitter.txt" 2>/dev/null || echo "null"),
      "packet_loss": "$(cat "$RESULTS_DIR/embb_packet_loss.txt" 2>/dev/null || echo "N/A")"
    },
    "urllc": {
      "latency_avg_ms": $(cat "$RESULTS_DIR/urllc_latency.txt" 2>/dev/null | tail -1 | awk -F'/' '{print $5}' || echo "null"),
      "jitter_ms": $(cat "$RESULTS_DIR/urllc_jitter.txt" 2>/dev/null || echo "null"),
      "packet_loss": "$(cat "$RESULTS_DIR/urllc_packet_loss.txt" 2>/dev/null || echo "N/A")"
    }
  }
}
EOFSUM

cat "$RESULTS_DIR/summary.json"
echo ""
echo "Benchmark complete!"
EOF

chmod +x benchmark.sh
```

### 3.5 Run Benchmarks

```bash
# Terminal 1: Start gNB
./build/nr-gnb -c config/open5gs-gnb.yaml &

# Wait for gNB to connect
sleep 5

# Terminal 2: Start eMBB UE
sudo ./build/nr-ue -c config/embb-ue.yaml &

# Wait for UE to register
sleep 10

# Run benchmark
sudo ./benchmark.sh
```

---

## 📊 STEP 4: Grafana Dashboards (30 minutes)

### 4.1 Import Open5GS Dashboard

Access Grafana at `http://<MONITORING_IP>:3000` (admin/admin)

Create a new dashboard with these panels:

### 4.2 Dashboard JSON

```json
{
  "dashboard": {
    "title": "Open5GS Monitoring",
    "panels": [
      {
        "title": "AMF Status",
        "type": "stat",
        "targets": [
          {
            "expr": "up{component=\"amf\"}",
            "legendFormat": "AMF"
          }
        ],
        "gridPos": { "h": 4, "w": 6, "x": 0, "y": 0 }
      },
      {
        "title": "UPF Status",
        "type": "stat",
        "targets": [
          {
            "expr": "up{component=\"upf\"}",
            "legendFormat": "UPF"
          }
        ],
        "gridPos": { "h": 4, "w": 6, "x": 6, "y": 0 }
      },
      {
        "title": "Active PDU Sessions",
        "type": "graph",
        "targets": [
          {
            "expr": "open5gs_smf_pdu_sessions_active",
            "legendFormat": "PDU Sessions"
          }
        ],
        "gridPos": { "h": 8, "w": 12, "x": 0, "y": 4 }
      },
      {
        "title": "UE Registrations",
        "type": "graph",
        "targets": [
          {
            "expr": "open5gs_amf_ue_registered_total",
            "legendFormat": "Registered UEs"
          }
        ],
        "gridPos": { "h": 8, "w": 12, "x": 12, "y": 4 }
      },
      {
        "title": "CPU Usage by VM",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "{{instance}}"
          }
        ],
        "gridPos": { "h": 8, "w": 12, "x": 0, "y": 12 }
      },
      {
        "title": "Memory Usage by VM",
        "type": "graph",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "legendFormat": "{{instance}}"
          }
        ],
        "gridPos": { "h": 8, "w": 12, "x": 12, "y": 12 }
      },
      {
        "title": "Network Traffic (RX)",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(node_network_receive_bytes_total{device!=\"lo\"}[5m]) * 8",
            "legendFormat": "{{instance}} - {{device}}"
          }
        ],
        "gridPos": { "h": 8, "w": 12, "x": 0, "y": 20 }
      },
      {
        "title": "Network Traffic (TX)",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(node_network_transmit_bytes_total{device!=\"lo\"}[5m]) * 8",
            "legendFormat": "{{instance}} - {{device}}"
          }
        ],
        "gridPos": { "h": 8, "w": 12, "x": 12, "y": 20 }
      }
    ]
  }
}
```

---

## 📋 STEP 5: 4G vs 5G Comparison (30 minutes)

### 5.1 Configure 4G eNB (UERANSIM)

```bash
gcloud compute ssh open5gs-ran --zone=$ZONE

cd ~/UERANSIM

cat > config/open5gs-enb.yaml << 'EOF'
mcc: '999'
mnc: '70'

nci: '0x000000020'
idLength: 32
tac: 1

linkIp: 10.10.0.100
gtpIp: 10.10.0.100
s1apIp: 10.10.0.100

mmeConfigs:
  - address: 10.10.0.2
    port: 36412
EOF

cat > config/4g-ue.yaml << 'EOF'
imsi: '999700000000003'
mcc: '999'
mnc: '70'

key: '465B5CE8B199B49FAA5F0A2EE238A6BC'
op: 'E8ED289DEBA952E4283B54E88E6183CA'
opType: 'OPC'
amf: '8000'

apn: 'internet'

# 4G Mode
rat: 'LTE'
EOF
```

### 5.2 Create Comparison Script

```bash
cat > compare_4g_5g.sh << 'EOF'
#!/bin/bash
# 4G vs 5G Comparison Script

RESULTS_DIR="comparison_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "============================================"
echo "4G vs 5G Performance Comparison"
echo "Date: $(date)"
echo "============================================"

# Test function
run_test() {
    local interface=$1
    local name=$2

    echo "Testing $name on $interface..."

    # Latency
    lat_result=$(ping -I $interface -c 50 8.8.8.8 2>/dev/null | tail -1 | awk -F'/' '{print $5}')

    # Jitter
    jitter=$(ping -I $interface -c 50 8.8.8.8 2>/dev/null | grep "time=" | \
             awk -F'time=' '{print $2}' | awk '{print $1}' | \
             awk '{sum+=$1; sq+=$1*$1; n++} END{mean=sum/n; print sqrt(sq/n-mean*mean)}')

    # Throughput
    speed=$(curl --interface $interface -o /dev/null -w '%{speed_download}' \
            http://speedtest.tele2.net/1MB.zip 2>/dev/null)
    speed_mbps=$(echo "scale=2; $speed / 1000000 * 8" | bc)

    echo "$name Results:"
    echo "  Latency: ${lat_result}ms"
    echo "  Jitter: ${jitter}ms"
    echo "  Throughput: ${speed_mbps} Mbps"
    echo ""

    # Save to file
    echo "{\"technology\": \"$name\", \"latency_ms\": $lat_result, \"jitter_ms\": $jitter, \"throughput_mbps\": $speed_mbps}" >> "$RESULTS_DIR/results.json"
}

# Run tests
echo ""
echo "=== 5G SA Tests ==="
if ip link show uesimtun0 &>/dev/null; then
    run_test uesimtun0 "5G-SA"
else
    echo "5G interface not available"
fi

echo ""
echo "=== 4G LTE Tests ==="
if ip link show uesimtun1 &>/dev/null; then
    run_test uesimtun1 "4G-LTE"
else
    echo "4G interface not available"
fi

# Generate comparison report
echo ""
echo "=== Comparison Summary ==="
cat "$RESULTS_DIR/results.json"

echo ""
echo "Results saved to: $RESULTS_DIR/"
EOF

chmod +x compare_4g_5g.sh
```

---

## 📊 STEP 6: QoS/QoE Analysis Report (15 minutes)

### 6.1 Generate Final Report

```bash
cat > generate_report.sh << 'EOF'
#!/bin/bash
# QoS/QoE Analysis Report Generator

REPORT_FILE="QoS_QoE_Report_$(date +%Y%m%d).md"

cat > $REPORT_FILE << 'REPORT'
# QoS/QoE Analysis Report

**Generated:** $(date)
**Environment:** Open5GS on GCP VMs

## 1. Executive Summary

This report presents the Quality of Service (QoS) and Quality of Experience (QoE)
analysis for the Open5GS deployment with 4G and 5G capabilities.

## 2. Test Configuration

| Parameter | Value |
|-----------|-------|
| Core Network | Open5GS v2.7.x |
| RAN Simulator | UERANSIM |
| MCC/MNC | 999/70 |
| 5G Slices | eMBB (SST=1), URLLC (SST=2) |

## 3. Performance Metrics

### 3.1 Latency Analysis

| Technology | Slice | Avg Latency | Min | Max | P99 |
|------------|-------|-------------|-----|-----|-----|
| 5G SA | eMBB | [VALUE]ms | [VALUE]ms | [VALUE]ms | [VALUE]ms |
| 5G SA | URLLC | [VALUE]ms | [VALUE]ms | [VALUE]ms | [VALUE]ms |
| 4G LTE | Default | [VALUE]ms | [VALUE]ms | [VALUE]ms | [VALUE]ms |

### 3.2 Throughput Analysis

| Technology | Download | Upload |
|------------|----------|--------|
| 5G eMBB | [VALUE] Mbps | [VALUE] Mbps |
| 5G URLLC | [VALUE] Mbps | [VALUE] Mbps |
| 4G LTE | [VALUE] Mbps | [VALUE] Mbps |

### 3.3 Jitter Analysis

| Technology | Slice | Jitter |
|------------|-------|--------|
| 5G SA | eMBB | [VALUE]ms |
| 5G SA | URLLC | [VALUE]ms |
| 4G LTE | Default | [VALUE]ms |

## 4. Slice Comparison

### eMBB (SST=1) vs URLLC (SST=2)

| Metric | eMBB | URLLC | Difference |
|--------|------|-------|------------|
| Latency | [VALUE]ms | [VALUE]ms | [DIFF]% |
| Jitter | [VALUE]ms | [VALUE]ms | [DIFF]% |
| Throughput | [VALUE] Mbps | [VALUE] Mbps | [DIFF]% |

## 5. 4G vs 5G Comparison

| Metric | 4G LTE | 5G SA | Improvement |
|--------|--------|-------|-------------|
| Latency | [VALUE]ms | [VALUE]ms | [DIFF]% faster |
| Throughput | [VALUE] Mbps | [VALUE] Mbps | [DIFF]x faster |
| Jitter | [VALUE]ms | [VALUE]ms | [DIFF]% lower |

## 6. QoE Scores

Based on ITU-T recommendations:

| Service | 4G Score | 5G Score |
|---------|----------|----------|
| Video Streaming | [1-5] | [1-5] |
| Voice Call | [1-5] | [1-5] |
| Gaming | [1-5] | [1-5] |
| IoT Sensors | [1-5] | [1-5] |

## 7. Conclusions

1. **5G provides [X]% lower latency** compared to 4G
2. **5G eMBB achieves [X]x higher throughput** than 4G
3. **URLLC slice shows [X]% lower jitter** compared to eMBB
4. **Network slicing enables differentiated QoS** for different use cases

## 8. Recommendations

1. Use eMBB slice for bandwidth-intensive applications
2. Use URLLC slice for latency-sensitive IoT deployments
3. Consider additional slices for specific vertical industries
4. Implement edge computing for further latency reduction

---
*Report generated by Open5GS Benchmark Suite*
REPORT

echo "Report generated: $REPORT_FILE"
EOF

chmod +x generate_report.sh
./generate_report.sh
```

---

## ✅ Phase 3 Validation Checklist

```
Monitoring:
[✓] Prometheus running and collecting metrics
[✓] Grafana accessible and dashboards created
[✓] Node Exporter running on all VMs
[✓] Alert rules configured

Network Slicing:
[✓] eMBB slice configured (SST=1, SD=000001)
[✓] URLLC slice configured (SST=2, SD=000002)
[✓] Subscribers created for each slice
[✓] UPF configured with multiple subnets

Benchmarking:
[✓] Benchmark script created
[✓] Latency tests completed
[✓] Throughput tests completed
[✓] Jitter tests completed
[✓] 4G vs 5G comparison done

Reports:
[✓] Performance data collected
[✓] QoS/QoE report generated
[✓] Slice comparison documented
```

---

## 🎓 Project Complete!

Congratulations! You have successfully deployed:

✅ **Phase 1:** Complete 4G/5G Core on GCP VMs  
✅ **Phase 2:** Terraform IaC + Ansible automation + CI/CD  
✅ **Phase 3:** Monitoring, Slicing, and Benchmarking

### Final Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                        GCP Project                              │
├────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐    ┌─────────────────────┐            │
│  │   Control Subnet     │    │    Data Subnet       │            │
│  │    10.10.0.0/24      │    │    10.11.0.0/24      │            │
│  │                      │    │                      │            │
│  │  ┌──────────────┐   │    │  ┌──────────────┐   │            │
│  │  │  MongoDB     │   │    │  │    UPF       │   │            │
│  │  │  10.10.0.4   │   │    │  │  10.11.0.7   │   │            │
│  │  └──────────────┘   │    │  └──────────────┘   │            │
│  │                      │    │         │           │            │
│  │  ┌──────────────┐   │    │         │           │            │
│  │  │ Control Plane │   │    │    GTP-U Traffic   │            │
│  │  │  10.10.0.2    │◄─┼────┼─────────┘           │            │
│  │  │ MME/AMF/NRF  │   │    │                      │            │
│  │  └──────────────┘   │    └─────────────────────┘            │
│  │         ▲           │                                        │
│  │         │           │                                        │
│  │  ┌──────────────┐   │    ┌─────────────────────┐            │
│  │  │  UERANSIM    │   │    │    Prometheus       │            │
│  │  │  10.10.0.100 │   │    │    Grafana          │            │
│  │  │  gNB + UEs   │   │    │    10.10.0.50       │            │
│  │  └──────────────┘   │    └─────────────────────┘            │
│  └─────────────────────┘                                        │
└────────────────────────────────────────────────────────────────┘
```

### Key Achievements

| Feature                        | Status        |
| ------------------------------ | ------------- |
| 4G EPC (MME, HSS, SGW, PGW)    | ✅ Deployed   |
| 5G Core (AMF, SMF, UPF, NRF)   | ✅ Deployed   |
| Network Slicing (eMBB + URLLC) | ✅ Configured |
| UERANSIM RAN Simulation        | ✅ Running    |
| Prometheus Monitoring          | ✅ Active     |
| Grafana Dashboards             | ✅ Created    |
| CI/CD Pipeline                 | ✅ Configured |
| Performance Benchmarks         | ✅ Completed  |

---

## 📚 References

- [Open5GS Official Documentation](https://open5gs.org/open5gs/docs/)
- [UERANSIM GitHub](https://github.com/aligungr/UERANSIM)
- [3GPP TS 23.501 - 5G System Architecture](https://www.3gpp.org/specifications)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

---

**Total Project Time:** 10-14 hours | **Status:** Complete ✅
