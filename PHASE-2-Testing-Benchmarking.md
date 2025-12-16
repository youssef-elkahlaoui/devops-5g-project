# PHASE 2: Testing & Benchmarking

**Duration:** 2-3 hours | **Complexity:** Intermediate | **Methodology:** Scientific comparison of 4G vs 5G

> **Prerequisites:** Complete [PHASE-1-VM-Infrastructure-Deployment.md](PHASE-1-VM-Infrastructure-Deployment.md) first. This phase assumes all infrastructure is provisioned and running.

---

## 📖 Phase Objectives

This phase proves the core thesis: **5G is fundamentally different from 4G from a cloud architecture perspective.**

- **4G Simulation:** Uses Physical Layer (Layer 1) - mathematically calculates radio waves
  - ➡️ Demonstrates why 4G needs heavy specialized hardware (DSP chips)
  - ➡️ Shows CPU limitations when virtualizing 4G
- **5G Simulation:** Uses Protocol Layer (Layer 3) - only simulates network messages
  - ➡️ Proves 5G is lightweight and cloud-native
  - ➡️ Shows why 5G scales efficiently in Kubernetes/containers

### Golden Rule of Testing

**⚠️ ISOLATION:** Never run 4G and 5G simulators simultaneously on vm-ran.

Why?

- Both consume CPU resources
- Both may try to bind to the same ports
- Results would be invalid (confounded variables)
- Run one scenario, record metrics, stop it, then switch to the other

This discipline ensures your benchmarking is scientifically valid.

---

## � Working Configuration Reference

This section contains all verified working configurations from PHASE-1. Use these as reference during testing.

### Network Parameters

```
Cloud Provider: Google Cloud Platform (GCP)
Zone: us-central1-a
VPC: open5gs-vpc (10.10.0.0/16)
Control Subnet: 10.10.0.0/24

PLMN Configuration (IMPORTANT - DO NOT CHANGE):
├── MCC: 999
├── MNC: 70
├── TAC: 1
└── Slices: SST=0 (default slice)

Subscriber Configuration:
├── IMSI: 999700000000001 or 999700000000002
├── Key (K): 465B5CE8B199B49FAA5F0A2EE238A6BC
├── OPc: E8ED289DEBA952E4283B54E88E6183CA
├── AMF: 8000
└── DNN: internet

UE Interface:
├── Interface: uesimtun0
├── Subnet: 10.45.0.0/16
├── Gateway: 10.45.0.1
└── DNS: 8.8.8.8, 8.8.4.4
```

### Core Network Ports (vm-core: 10.10.0.2)

| Service     | Protocol | Port  | Direction  |
| ----------- | -------- | ----- | ---------- |
| NRF         | HTTP/2   | 7777  | Internal   |
| AMF         | SCTP     | 38412 | From RAN   |
| AMF         | HTTP/2   | 7778  | Internal   |
| SMF         | HTTP/2   | 7776  | Internal   |
| UDM         | HTTP/2   | 7780  | Internal   |
| UDR         | HTTP/2   | 7783  | Internal   |
| PCF         | HTTP/2   | 7781  | Internal   |
| AUSF        | HTTP/2   | 7779  | Internal   |
| UPF (PFCP)  | UDP      | 8805  | From SMF   |
| UPF (GTP-U) | UDP      | 2152  | From RAN   |
| GTP-C       | UDP      | 2123  | From SMF   |
| MongoDB     | TCP      | 27017 | Local only |

### UERANSIM Configuration

**gNB (5G Base Station):** `~/UERANSIM/config/open5gs-gnb.yaml`

```yaml
mcc: "999"
mnc: "70"
nci: "0x000000010"
tac: 1
linkIp: 10.10.0.100
ngapIp: 10.10.0.100
gtpIp: 10.10.0.100
amfConfigs:
  - address: 10.10.0.2
    port: 38412
slices:
  - sst: 0
ignoreStreamIds: true
```

**UE (5G User Equipment):** `~/UERANSIM/config/open5gs-ue.yaml`

```yaml
supi: "imsi-999700000000001"
mcc: "999"
mnc: "70"
key: "465B5CE8B199B49FAA5F0A2EE238A6BC"
op: "E8ED289DEBA952E4283B54E88E6183CA"
opType: "OPC"
amf: "8000"
gnbSearchList: [10.10.0.100]
sessions:
  - type: "IPv4"
    apn: "internet"
    slice: { sst: 0 }
configured-nssai: [{ sst: 0 }]
default-nssai: [{ sst: 0 }]
integrity: { IA1: false, IA2: true, IA3: false }
ciphering: { EA1: false, EA2: true, EA3: false }
integrityMaxRate: { uplink: "full", downlink: "full" }
```

### Performance Baselines

| Metric               | Value         |
| -------------------- | ------------- |
| gNB Connection Time  | < 5 seconds   |
| UE Registration Time | 30-60 seconds |
| Session Setup Time   | 10-15 seconds |
| Ping Success Rate    | > 99%         |
| Average Latency      | 8-12ms        |
| Throughput           | 200-500 Mbps  |

### Health Check Commands

```bash
# SSH into vm-core
gcloud compute ssh vm-core --zone=us-central1-a

# Check all services are running
sudo systemctl status open5gs-*

# Verify AMF listening on SCTP 38412
sudo netstat -tlnup | grep 38412

# Check MongoDB
mongosh --eval "db.adminCommand('ping')"

# View recent AMF logs
journalctl -u open5gs-amfd -n 50

# SSH into vm-ran
gcloud compute ssh vm-ran --zone=us-central1-a

# Start gNB
cd ~/UERANSIM
timeout 15 ./build/nr-gnb -c config/open5gs-gnb.yaml

# In another terminal on vm-ran, start UE
sudo ./build/nr-ue -c config/open5gs-ue.yaml

# Test connectivity
sudo ip addr show uesimtun0
sudo ping -I uesimtun0 -c 5 8.8.8.8
```

### Common Issues & Solutions

| Issue                           | Root Cause            | Solution                                                              |
| ------------------------------- | --------------------- | --------------------------------------------------------------------- |
| gNB shows "slice-not-supported" | Slice config mismatch | Verify gNB has `slices: [{sst: 0}]`, AMF has `s_nssai: [{sst: 0}]`    |
| UE can't find cell              | gNB not accessible    | Check `ps aux \| grep nr-gnb`, verify port 38412 open, check firewall |
| MongoDB connection failed       | MongoDB not running   | `sudo systemctl restart mongod`                                       |
| AMF won't start                 | Missing PLMN config   | Verify MCC=999, MNC=70 in all configs, check YAML syntax              |

---

## �📊 Benchmarking Methodology

### The Contrast: Physical Layer vs Protocol Layer

| Aspect                        | 4G (srsRAN Physical Layer)                 | 5G (UERANSIM Protocol Layer)                         |
| ----------------------------- | ------------------------------------------ | ---------------------------------------------------- |
| **Simulation Scope**          | Layer 1 (Modulation, fading, interference) | Layer 3 (Message signaling only)                     |
| **Architectural Implication** | Radio simulation is **CPU-intensive**      | Network simulation is **message-based**              |
| **Expected CPU Usage**        | 80-100% (radio math is heavy)              | <10% (just passing messages)                         |
| **Expected Throughput**       | 15-30 Mbps (bottlenecked by CPU)           | 200-500 Mbps (network bandwidth limited)             |
| **Deployment Model**          | Requires specialized hardware (DSP)        | Cloud-native (containers, VMs, serverless)           |
| **Scalability in Cloud**      | Poor (one VM ≈ one cell tower)             | Excellent (one container ≈ thousands of subscribers) |

### Key Performance Metrics

| Metric                   | 4G Target  | 5G Target    | Why It Matters                               |
| ------------------------ | ---------- | ------------ | -------------------------------------------- |
| **Registration Latency** | 100-150ms  | 40-60ms      | Measures UE attachment speed                 |
| **Throughput**           | 15-30 Mbps | 200-500 Mbps | Proves 5G's raw speed advantage              |
| **User Plane Latency**   | 15-20ms    | 5-8ms        | Proves 5G's responsiveness                   |
| **CPU Usage (RAN VM)**   | 80-100%    | <10%         | **PRIMARY EVIDENCE:** Why 5G is cloud-native |
| **Jitter**               | 8-12ms     | 2-3ms        | Shows 5G's consistency                       |
| **Packet Loss**          | <0.5%      | <0.1%        | Shows reliability difference                 |

---

## 📋 Understanding Your Test Scenarios

### Scenario A: 4G Legacy Benchmark (srsRAN)

**Context:**

- srsRAN simulates the **physical layer (Layer 1)** of LTE
- It mathematically models signal modulation (QPSK, 16-QAM), fading channels, and interference
- This is computationally equivalent to running a Real Base Station's Digital Signal Processing (DSP)

**The Setup:**

```bash
# Terminal 1: Start base station (eNB)
srsenb --rf.device_name=zmq --rf.device_args="tx_port=tcp://*:2000,rx_port=tcp://127.0.0.1:2001"

# Terminal 2: Start user equipment (UE) in network namespace
ip netns add ue_ns
srsue --rf.device_name=zmq --rf.device_args="tx_port=tcp://127.0.0.1:2001,rx_port=tcp://*:2000"
```

**Expected Behavior:**

- RAN VM CPU usage: **80-100%** (radio math is heavy)
- Throughput: **15-30 Mbps** (CPU-bottlenecked, not network)
- Latency: **50-100ms** (processing delay from radio simulation)

**Narrative:** This demonstrates why 4G towers require specialized hardware (DSP chips) and why virtualizing legacy RAN is inefficient. The CPU is the bottleneck, not the network.

### Scenario B: 5G Cloud-Native Benchmark (UERANSIM)

**Context:**

- UERANSIM operates at the **protocol layer (Layer 3)**
- It simulates 5G NR protocol signaling (RRC, NAS, NGAP messages) without the physical layer
- This is fundamentally lighter-weight because it doesn't mathematically model radio waves

**The Setup:**

```bash
# Terminal 1: Start gNodeB
./nr-gnb -c config/open5gs-gnb.yaml

# Terminal 2: Start UE
sudo ./nr-ue -c config/open5gs-ue.yaml

# Terminal 3: Test internet access
sudo ping -I uesimtun0 8.8.8.8
```

**Expected Behavior:**

- RAN VM CPU usage: **<10%** (just passing messages)
- Throughput: **200-500 Mbps** (network bandwidth limited, not CPU)
- Latency: **5-8ms** (minimal processing)

**Narrative:** This proves that 5G Core architecture is lightweight, efficient, and perfectly suited for cloud deployment (Kubernetes, containers, serverless). The network is the bottleneck, not the CPU.

### The Comparison Insight

**Why does this matter for your final report?**

4G: CPU-bound = Specialized hardware = On-premises towers = Non-scalable in cloud  
5G: Network-bound = Commodity hardware = Cloud-deployable = Highly scalable

This architectural difference is why cloud providers (AWS, Azure, GCP) are investing in 5G core while legacy 4G remains centralized.

---

## 🧪 Step 1: Setup Test Environment (30 minutes)

### 1.1 Configure Logging

On **vm-core**, enable detailed logging:

```bash
# Update AMF logging
sudo tee /etc/open5gs/amf.yaml > /dev/null << 'EOF'
# ... (keep existing config) ...
logger:
  file: /var/log/open5gs/amf.log
  level: debug
  max_size: 10485760
  number_of_files: 20
EOF

sudo systemctl restart open5gs-amfd
```

### 1.2 Create Test Scripts

On **vm-ran**, create `test_connectivity.sh`:

```bash
#!/bin/bash

echo "=== 5G Network Connectivity Test ==="
echo "Time: $(date)"

# Check uesimtun0 interface
echo -e "\n[1/5] Checking UE interface..."
ip addr show uesimtun0

# Test DNS resolution
echo -e "\n[2/5] Testing DNS..."
dig @8.8.8.8 google.com +short

# Ping test
echo -e "\n[3/5] Running ping test..."
ping -I uesimtun0 -c 10 -W 1 8.8.8.8

# Throughput test
echo -e "\n[4/5] Checking interface stats..."
ip -s link show uesimtun0

# Network trace
echo -e "\n[5/5] Network configuration..."
ip route show
```

Make executable:

```bash
chmod +x test_connectivity.sh
./test_connectivity.sh
```

### 1.3 Create Throughput Test Script

Create `test_throughput.sh`:

```bash
#!/bin/bash

if ! command -v iperf3 &> /dev/null; then
  echo "Installing iperf3..."
  sudo apt install -y iperf3
fi

echo "=== Throughput Test ==="

# Server mode on vm-core
# (Run in separate terminal on vm-core):
# iperf3 -s

# Client mode on vm-ran
echo "Starting throughput test..."
iperf3 -c 10.45.0.1 -t 30 -i 5 -R

echo "Test complete"
```

---

## 📈 Step 2: Prometheus Setup (45 minutes)

### 2.1 Install Prometheus

On **vm-core**:

```bash
# Download Prometheus
cd /tmp
curl -L https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz | tar xz
cd prometheus-2.48.0.linux-amd64

# Copy to system location
sudo cp prometheus /usr/local/bin/
sudo cp promtool /usr/local/bin/
sudo mkdir -p /etc/prometheus /var/lib/prometheus
```

### 2.2 Configure Prometheus

Create `/etc/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: "open5gs"
    environment: "production"

scrape_configs:
  - job_name: "open5gs-amf"
    static_configs:
      - targets: ["localhost:9090"]
    metrics_path: "/metrics"

  - job_name: "open5gs-smf"
    static_configs:
      - targets: ["localhost:9091"]

  - job_name: "open5gs-upf"
    static_configs:
      - targets: ["localhost:9092"]

  - job_name: "node-metrics"
    static_configs:
      - targets: ["localhost:9100"]

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["localhost:9093"]

rule_files:
  - "/etc/prometheus/alert-rules.yml"
```

### 2.3 Create Alert Rules

Create `/etc/prometheus/alert-rules.yml`:

```yaml
groups:
  - name: open5gs
    interval: 30s
    rules:
      - alert: HighCPUUsage
        expr: node_cpu_usage > 0.8
        for: 5m
        annotations:
          summary: "High CPU usage detected"

      - alert: HighMemoryUsage
        expr: node_memory_usage > 0.75
        for: 5m
        annotations:
          summary: "High memory usage detected"

      - alert: ServiceDown
        expr: up{job="open5gs-amf"} == 0
        for: 1m
        annotations:
          summary: "Open5GS service is down"

      - alert: HighLatency
        expr: network_latency_ms > 100
        for: 5m
        annotations:
          summary: "Network latency exceeds 100ms"
```

### 2.4 Create Systemd Service

Create `/etc/systemd/system/prometheus.service`:

```ini
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus
Restart=always

[Install]
WantedBy=multi-user.target
```

### 2.5 Start Prometheus

```bash
# Create prometheus user
sudo useradd --no-create-home --shell /bin/false prometheus

# Set permissions
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

# Verify
curl http://localhost:9090
```

---

## 📊 Step 3: Grafana Setup (45 minutes)

### 3.1 Install Grafana

```bash
sudo apt install -y grafana-server
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
```

### 3.2 Access Grafana

1. Open browser: `http://<vm-core-public-ip>:3000`
2. Login: admin / admin
3. Change password when prompted

### 3.3 Add Prometheus Data Source

1. Go to **Configuration** → **Data Sources**
2. Click **Add data source**
3. Select **Prometheus**
4. URL: `http://localhost:9090`
5. Save & Test

### 3.4 Create Dashboard for 5G Metrics

1. Click **+** → **Dashboard**
2. Click **Add new panel**
3. Add panels for:

**Panel 1: Registration Success Rate**

```
Query: rate(open5gs_amf_registration_success_total[5m]) * 100
Graph: Time series
Unit: percent
```

**Panel 2: Session Establishment Latency**

```
Query: histogram_quantile(0.95, open5gs_smf_session_setup_latency_seconds)
Graph: Gauge
Unit: milliseconds
Thresholds: [0-50, 50-100, 100+]
```

**Panel 3: Throughput (5G)**

```
Query: rate(open5gs_upf_bytes_transmitted_total[5m]) * 8 / 1000000
Graph: Time series
Unit: Mbps
```

**Panel 4: CPU Usage (vm-core)**

```
Query: node_cpu_usage * 100
Graph: Time series
Unit: percent
```

**Panel 5: Memory Usage (vm-core)**

```
Query: (1 - (node_memory_MemAvailable / node_memory_MemTotal)) * 100
Graph: Gauge
Unit: percent
```

**Panel 6: Packet Loss Rate**

```
Query: rate(open5gs_upf_packets_dropped_total[5m]) / rate(open5gs_upf_packets_total[5m])
Graph: Time series
Unit: short
```

### 3.5 Save Dashboard

1. Click **Save dashboard**
2. Name: "5G Network Performance"
3. Save

---

## 🎯 Step 4: Network Slicing Configuration (30 minutes)

### 4.1 Add eMBB Slice (Enhanced Mobile Broadband)

In Open5GS WebUI (http://<vm-core-ip>:3000):

1. Subscribers → test-user → Edit
2. Slices section
3. Add new slice:
   - **SST:** 1
   - **SD:** 000001
   - **DNN:** internet
   - **QoS Class:** Class 1 (eMBB - High throughput)

### 4.2 Add URLLC Slice (Ultra-Reliable Low Latency)

1. Add new slice:
   - **SST:** 2
   - **SD:** 000002
   - **DNN:** mission-critical
   - **QoS Class:** Class 2 (URLLC - Low latency)

### 4.3 Update SMF Configuration

Edit `/etc/open5gs/smf.yaml`:

```yaml
# ... existing config ...
slice:
  - sst: 0
    dnn: internet
  - sst: 1
    sd: 000001
    dnn: internet
    qos:
      index: 9
      arp:
        priority_level: 6
  - sst: 2
    sd: 000002
    dnn: mission-critical
    qos:
      index: 7
      arp:
        priority_level: 1
```

### 4.4 Restart Services

```bash
sudo systemctl restart open5gs-smfd
```

---

## 📋 Step 5: Performance Testing (60 minutes)

### 5.1 Registration Latency Test

Create `test_registration_latency.sh`:

```bash
#!/bin/bash

ITERATIONS=10
TOTAL=0

echo "=== Registration Latency Test ==="
echo "Running $ITERATIONS registration attempts..."

for i in $(seq 1 $ITERATIONS); do
  # Kill previous UE
  sudo killall -9 nr-ue 2>/dev/null
  sleep 2

  # Start UE and measure time
  START=$(date +%s%N)
  timeout 30 sudo ./build/nr-ue -c config/open5gs-ue.yaml > /tmp/ue-$i.log 2>&1 &
  UE_PID=$!

  # Wait for registration
  while ! grep -q "MM-REGISTERED" /tmp/ue-$i.log; do
    if ! kill -0 $UE_PID 2>/dev/null; then
      echo "Process died, skipping iteration $i"
      continue 2
    fi
    sleep 0.1
  done

  END=$(date +%s%N)
  LATENCY=$((($END - $START) / 1000000)) # Convert to ms

  echo "Attempt $i: ${LATENCY}ms"
  TOTAL=$((TOTAL + LATENCY))

  kill $UE_PID 2>/dev/null
done

AVG=$((TOTAL / ITERATIONS))
echo -e "\nAverage Registration Latency: ${AVG}ms"
```

### 5.2 Throughput Test

Create `test_throughput_5g.sh`:

```bash
#!/bin/bash

echo "=== 5G Throughput Test ==="

# Ensure gNB is running (in separate terminal)
# ./build/nr-gnb -c config/open5gs-gnb.yaml

# Ensure UE is registered
timeout 30 sudo ./build/nr-ue -c config/open5gs-ue.yaml &
UE_PID=$!

# Wait for registration
sleep 20

# Run iperf3 on vm-core (server):
# iperf3 -s

# Run iperf3 client on vm-ran
echo "Running throughput test (30 seconds)..."
iperf3 -c 10.45.0.1 -t 30 -i 5 -J > throughput_results.json

# Parse results
THROUGHPUT=$(cat throughput_results.json | grep '"bits_per_second"' | tail -1 | awk -F: '{print $2}' | sed 's/[^0-9.]//g')
THROUGHPUT_MBPS=$((THROUGHPUT / 1000000))

echo "Average Throughput: ${THROUGHPUT_MBPS} Mbps"

kill $UE_PID
```

### 5.3 Latency Test

Create `test_latency.sh`:

```bash
#!/bin/bash

echo "=== User Plane Latency Test ==="

# Must have UE registered with uesimtun0 interface
echo "Pinging 8.8.8.8 through 5G network..."

# Standard ping test (10 packets)
ping -I uesimtun0 -c 10 -W 2 8.8.8.8 | tail -n 1

# Advanced: measure 100 packets for better statistics
RESULT=$(ping -I uesimtun0 -c 100 -W 2 8.8.8.8)
echo "$RESULT" | tail -n 1

# Extract metrics
MIN=$(echo "$RESULT" | tail -1 | awk -F'/' '{print $4}' | cut -d'.' -f1)
AVG=$(echo "$RESULT" | tail -1 | awk -F'/' '{print $5}' | cut -d'.' -f1)
MAX=$(echo "$RESULT" | tail -1 | awk -F'/' '{print $6}' | cut -d' ' -f1 | cut -d'.' -f1)

echo "Results Summary:"
echo "  Minimum: ${MIN}ms"
echo "  Average: ${AVG}ms"
echo "  Maximum: ${MAX}ms"
```

---

## 📊 Step 6: Data Collection & Analysis (30 minutes)

### 6.1 Create Test Report

Create `test_report.sh`:

```bash
#!/bin/bash

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="test_results_$TIMESTAMP"

mkdir -p $REPORT_DIR

echo "=== 5G Network Performance Report ===" > $REPORT_DIR/summary.txt
echo "Generated: $(date)" >> $REPORT_DIR/summary.txt
echo "" >> $REPORT_DIR/summary.txt

# Run all tests
echo "Running connectivity test..."
./test_connectivity.sh > $REPORT_DIR/connectivity.log

echo "Running throughput test..."
./test_throughput_5g.sh > $REPORT_DIR/throughput.log

echo "Running latency test..."
./test_latency.sh > $REPORT_DIR/latency.log

echo "Running registration latency test..."
./test_registration_latency.sh > $REPORT_DIR/registration.log

echo "Tests complete. Results saved to: $REPORT_DIR"
```

### 6.2 Collect Prometheus Metrics

```bash
# Export metrics for analysis
curl http://localhost:9090/api/v1/query_range \
  ?query=open5gs_amf_registration_success_total \
  ?start=$(date -d '1 hour ago' +%s) \
  ?end=$(date +%s) \
  ?step=60 > metrics.json
```

---

## 📈 Step 7: Visualization & Reporting (30 minutes)

### 7.1 Export Grafana Dashboards

1. Go to Grafana dashboard
2. Click **Share** → **Export**
3. Save as JSON
4. Include in final report

### 7.2 Create Comparison Table

Create a benchmark comparison:

| Metric               | 4G       | 5G       | Improvement |
| -------------------- | -------- | -------- | ----------- |
| Registration Latency | 150ms    | 60ms     | 60%         |
| Throughput           | 100 Mbps | 500 Mbps | 400%        |
| User Plane Latency   | 20ms     | 5ms      | 75%         |
| Jitter               | 10ms     | 2ms      | 80%         |
| CPU Usage            | 90%      | 15%      | 83%         |

### 7.3 Generate PDF Report

Use any PDF tool to create:

```
5G Network Performance Report
├── Executive Summary
├── Test Methodology
├── Benchmark Results
│   ├── Throughput Comparison
│   ├── Latency Analysis
│   ├── Resource Utilization
│   └── Network Slicing Performance
├── Grafana Dashboard Screenshots
└── Conclusions & Recommendations
```

---

---

## 📋 Final Report Structure

When compiling your findings into a final project submission, use this outline:

### 1. Architecture Diagram

Visual representation showing:

- Two-VM setup (vm-core and vm-ran)
- Network tunnels (SCTP 38412 for NGAP, GTP-U 2152 for data, PFCP 8805)
- Separation of Core and RAN
- Why this architecture proves cloud-native suitability

### 2. Infrastructure as Code (Terraform)

- Snippet showing VM provisioning with e2-medium constraints
- Firewall rule explanation (SCTP, GTP, HTTP/2, PFCP protocols)
- VPC and subnet design
- **Narrative:** How Terraform replaces manual clicking

### 3. Configuration Management (Ansible)

- Snippet showing IP binding requirement (127.0.0.1 → 10.10.0.2)
- NAT masquerading rules (iptables configuration)
- Compilation of srsRAN vs UERANSIM (source build process)
- **Narrative:** How Ansible ensures idempotency and reproducibility

### 4. Benchmarking Results Table

| Metric         | 4G (srsRAN) | 5G (UERANSIM) | Improvement   | Implication                 |
| -------------- | ----------- | ------------- | ------------- | --------------------------- |
| CPU Usage      | 85%         | 8%            | 91% reduction | 10x more subscribers per VM |
| Throughput     | 22 Mbps     | 420 Mbps      | 19x increase  | Better user experience      |
| Latency        | 75ms        | 12ms          | 84% reduction | Lower perceived delay       |
| Jitter         | 10ms        | 2.5ms         | 75% reduction | Consistent QoE              |
| Estimated Cost | $65/month   | $8/month      | 87% savings   | Business case for 5G        |

### 5. Grafana Dashboard Screenshots

Capture:

- **The CPU Contrast** - Side-by-side time series showing 4G spike vs 5G flatline
- **The Throughput Jump** - Bar chart showing 19x improvement
- **The Latency Stability** - Jitter graph showing 5G consistency

### 6. Conclusion Statement

**Template:**

_"This project demonstrates that 5G Core architecture is fundamentally suited for cloud deployment while legacy 4G requires specialized hardware. The evidence is clear: 5G achieves 19x higher throughput while using 91% less CPU. This architectural difference explains why public cloud providers are investing heavily in 5G core services while legacy 4G remains centralized. The cost reduction (87% savings) alone justifies the migration, before considering performance improvements."_

---

## ✅ Phase 2 Completion Checklist

Phase 2 is complete when:

- ✅ Prometheus collecting metrics from Open5GS services
- ✅ Grafana dashboard created with story-telling panels
- ✅ 4G scenario run (srsRAN) with metrics recorded
- ✅ 5G scenario run (UERANSIM) with metrics recorded
- ✅ Scenarios isolated (never simultaneous)
- ✅ Performance data table compiled
- ✅ Dashboard screenshots captured
- ✅ Final report structure complete

---

## 📊 Expected Results

### Typical Benchmark Outcomes

**Connectivity:**

- ✅ Registration Success Rate: > 99%
- ✅ Session Setup Time: < 100ms
- ✅ Packet Loss: < 0.1%

**Performance:**

- ✅ Throughput: 200-500 Mbps
- ✅ User Plane Latency: 5-15ms
- ✅ Jitter: 2-5ms

**Resource Efficiency:**

- ✅ CPU Usage: 10-20% (per service)
- ✅ Memory Usage: 500-800 MB (per service)
- ✅ Network Overhead: < 5%

---

## 🎯 Next Steps

1. **Document Results** - Create final project report
2. **Archive Data** - Save all test logs and metrics
3. **Presentation** - Prepare presentation of findings

---

**Status:** Phase 2 Complete ✅ | **Duration:** 2-4 hours | **Complexity:** Intermediate
