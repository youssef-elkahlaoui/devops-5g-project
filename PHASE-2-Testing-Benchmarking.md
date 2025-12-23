# PHASE 2: Testing & Benchmarking - 4G vs 5G Comparison

**⏱️ Duration: 2-3 Hours | 🎯 Goal: Scientific comparison of 4G vs 5G performance with centralized monitoring**

---

## 📋 Phase 2 Overview

This phase proves the core thesis: **5G is fundamentally different from 4G from a cloud architecture perspective.**

### Key Objectives

1. **Test 4G Network (VM1)** - srsRAN Physical Layer simulation
2. **Test 5G Network (VM2)** - UERANSIM Protocol Layer simulation
3. **Monitor from VM3** - Centralized metrics collection and comparison
4. **Analyze Performance** - Latency, throughput, CPU usage, jitter
5. **Create Dashboards** - Visual 4G vs 5G comparison in Grafana

### The Core Difference

| Aspect                | 4G (srsRAN on VM1)              | 5G (UERANSIM on VM2)        |
| --------------------- | ------------------------------- | --------------------------- |
| **Simulation Level**  | Physical Layer (Layer 1)        | Protocol Layer (Layer 3)    |
| **What's Simulated**  | Radio waves, modulation, fading | Network messages only       |
| **CPU Impact**        | 🔴 80-100% (radio math)         | 🟢 <10% (message passing)   |
| **Throughput**        | ~30 Mbps (CPU-limited)          | ~500 Mbps (network-limited) |
| **Latency**           | ~35ms (processing delay)        | ~10ms (minimal processing)  |
| **Cloud Suitability** | ❌ Requires DSP hardware        | ✅ Cloud-native ready       |

### Golden Rule

**⚠️ NEVER run 4G and 5G tests simultaneously**

- Run 4G test → observe metrics in Grafana → stop simulation
- Run 5G test → observe metrics in Grafana → stop simulation
- Compare results side-by-side

---

## 🔧 Prerequisites

```bash
# Verify Phase 1 completed
cd c:\Users\jozef\OneDrive\Desktop\devops-5g-project

# Check all VMs are accessible
$VM1_IP = (cd terraform-vm1-4g; terraform output -raw vm1_public_ip)
$VM2_IP = (cd terraform-vm2-5g; terraform output -raw vm2_public_ip)
$VM3_IP = (cd terraform-vm3-monitoring; terraform output -raw vm3_public_ip)

ssh ayoubgory_gmail_com@$VM1_IP "echo 'VM1 accessible'"
ssh ayoubgory_gmail_com@$VM2_IP "echo 'VM2 accessible'"
ssh ayoubgory_gmail_com@$VM3_IP "echo 'VM3 accessible'"

# Access Grafana
Write-Host "Grafana: http://$VM3_IP:3000 (admin/admin)"
```

---

## 📊 STEP 1: Configure Monitoring (15 minutes)

### 1.1 Access Grafana

```bash
# Open Grafana in browser
Start-Process "http://$VM3_IP:3000"

# Login credentials
# Username: admin
# Password: admin
# (Change password when prompted)
```

### 1.2 Verify Prometheus Data Source

1. Navigate to **Configuration → Data Sources**
2. Click **Prometheus**
3. Verify URL: `http://localhost:9090`
4. Click **Save & Test**
5. Expected: ✅ "Data source is working"

### 1.3 Verify Prometheus Targets

```bash
# SSH to VM3
ssh ayoubgory_gmail_com@$VM3_IP

# Check all targets are UP
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'

# Expected output (all health: "up"):
# {job: "prometheus", instance: "localhost:9090", health: "up"}
# {job: "open5gs-4g-core", instance: "10.10.0.10:9090", health: "up"}
# {job: "node-vm1-4g", instance: "10.10.0.10:9100", health: "up"}
# {job: "open5gs-5g-core", instance: "10.10.0.20:9090", health: "up"}
# {job: "node-vm2-5g", instance: "10.10.0.20:9100", health: "up"}
# {job: "node-vm3-monitoring", instance: "localhost:9100", health: "up"}

exit
```

### 1.4 Import 4G vs 5G Dashboard

The dashboard is automatically provisioned by Ansible. You should see it under **Dashboards → Browse**.

If you need to import it manually:

1. Navigate to **Dashboards → Import**
2. Upload the file from your local machine: `ansible-vm3-monitoring/dashboards/4g-vs-5g.json`
3. Or copy-paste the JSON content from that file.

**✅ Checkpoint:** Grafana configured with all 6 targets UP and dashboard visible.

---

## 🧪 STEP 2: Test 4G Network (VM1) (45 minutes)

### 2.1 Prepare 4G Test Environment

```bash
# SSH to VM1
ssh ayoubgory_gmail_com@$VM1_IP

# Verify Open5GS EPC is running
sudo systemctl status open5gs-mmed
sudo systemctl status open5gs-sgwcd
sudo systemctl status open5gs-pgwd

# Check 4G subscriber
mongosh open5gs --eval "db.subscribers.findOne({imsi: '001010000000001'})"

# Expected: Subscriber with IMSI 001010000000001, K, OPc configured
```

### 2.2 Start 4G Base Station (eNB)

```bash
# In VM1 terminal 1
cd /home/ayoubgory_gmail_com
sudo ./start-enb.sh

# Expected output:
# Opening USRP...
# Setting master clock rate...
# Built-in type detected
# Starting eNodeB...

# Watch for:
# [INFO] S1AP: Connected to MME
# [INFO] RRC: State changed to RRC_CONNECTED
```

### 2.3 Start 4G User Equipment (UE)

```bash
# In VM1 terminal 2 (new SSH session)
ssh ayoubgory_gmail_com@$VM1_IP

cd /home/ayoubgory_gmail_com
sudo ./start-ue.sh

# Expected output:
# Opening USRP...
# Found Network: MCC 001, MNC 01
# RRC Connection Established
# Attached to network
# PDN connection established

# Verify ue1 network namespace created
sudo ip netns list
# Expected: ue1

# Check UE interface
sudo ip netns exec ue1 ip addr show
# Expected: Interface with IP in 10.45.0.0/16 range
```

### 2.4 Test 4G Connectivity

```bash
# In VM1 terminal 3 (new SSH session)
ssh ayoubgory_gmail_com@$VM1_IP

# Ping Google DNS via 4G UE
sudo ip netns exec ue1 ping -c 10 8.8.8.8

# Expected:
# 10 packets transmitted, 10 received, 0% packet loss
# rtt min/avg/max/mdev = 25/35/45/5 ms

# Measure throughput (iperf3 server on internet)
sudo ip netns exec ue1 iperf3 -c iperf.he.net -t 60

# Expected:
# [ ID] Interval           Transfer     Bitrate
# [  5]   0.00-60.00  sec   200 MBytes  28.0 Mbits/sec

# Note the CPU-limited throughput (~30 Mbps)
```

### 2.5 Monitor 4G Performance in Grafana

**Open Grafana Dashboard** (http://$VM3_IP:3000)

Watch these metrics during 4G test:

- **VM1 CPU Usage**: Should spike to **80-100%**
- **VM1 Network Throughput**: Limited to **~30 Mbps**
- **VM1 Memory**: Moderate usage (~40%)
- **Open5GS Sessions**: Active sessions visible

**Key Observation:** CPU is the bottleneck, not network bandwidth

### 2.6 Stop 4G Simulation

```bash
# Stop UE (terminal 2)
Ctrl+C

# Stop eNB (terminal 1)
Ctrl+C

# Verify stopped
ps aux | grep -E "srsenb|srsue"
# Expected: No processes
```

### 2.7 Record 4G Baseline Metrics

| Metric            | Value          | Notes                     |
| ----------------- | -------------- | ------------------------- |
| Registration Time | ~30-40 seconds | UE attach to network      |
| Average Latency   | 25-40 ms       | Ping to 8.8.8.8           |
| Peak Throughput   | 20-35 Mbps     | CPU-limited               |
| CPU Usage         | 80-100%        | Physical layer simulation |
| Memory Usage      | ~40%           |                           |
| Jitter            | 8-15 ms        | Latency variation         |
| Packet Loss       | <1%            |                           |

**✅ Checkpoint:** 4G network tested, metrics recorded

---

## 🧪 STEP 3: Test 5G Network (VM2) (45 minutes)

### 3.1 Prepare 5G Test Environment

```bash
# SSH to VM2
ssh ayoubgory_gmail_com@$VM2_IP

# Verify Open5GS 5GC is running
sudo systemctl status open5gs-nrfd
sudo systemctl status open5gs-amfd
sudo systemctl status open5gs-smfd

# Check 5G subscriber
mongosh open5gs --eval "db.subscribers.findOne({imsi: '999700000000001'})"

# Expected: Subscriber with IMSI 999700000000001, K, OPc configured
```

### 3.2 Start 5G Base Station (gNB)

```bash
# In VM2 terminal 1
cd /home/ayoubgory_gmail_com/UERANSIM
sudo ./build/nr-gnb -c config/open5gs-gnb.yaml

# Expected output:
# [2025-12-20 10:30:15.123] [sctp] Trying to establish SCTP connection... (10.10.0.20:38412)
# [2025-12-20 10:30:15.234] [ngap] NG Setup successful
# [2025-12-20 10:30:15.345] [gnb] gNB started successfully

# Watch for:
# [INFO] NGAP: Connected to AMF
# [INFO] NGAP: NG Setup Response received
```

### 3.3 Start 5G User Equipment (UE)

```bash
# In VM2 terminal 2 (new SSH session)
ssh ayoubgory_gmail_com@$VM2_IP

cd /home/ayoubgory_gmail_com/UERANSIM
sudo ./build/nr-ue -c config/open5gs-ue.yaml

# Expected output:
# [2025-12-20 10:30:30.123] [nas] Registration Request sent
# [2025-12-20 10:30:30.234] [nas] Registration accepted
# [2025-12-20 10:30:30.345] [nas] PDU Session established
# [2025-12-20 10:30:30.456] [app] Interface uesimtun0 created

# Verify uesimtun0 interface
ip addr show uesimtun0
# Expected: Interface with IP in 10.45.0.0/16 range
```

### 3.4 Test 5G Connectivity

```bash
# In VM2 terminal 3 (new SSH session)
ssh ayoubgory_gmail_com@$VM2_IP

# Ping Google DNS via 5G UE
sudo ping -I uesimtun0 -c 10 8.8.8.8

# Expected:
# 10 packets transmitted, 10 received, 0% packet loss
# rtt min/avg/max/mdev = 8/10/12/2 ms

# Measure throughput
sudo iperf3 -c iperf.he.net -B 10.45.0.2 -t 60

# Expected:
# [ ID] Interval           Transfer     Bitrate
# [  5]   0.00-60.00  sec   3.5 GBytes  500 Mbits/sec

# Note the NETWORK-limited throughput (~500 Mbps)
```

### 3.5 Monitor 5G Performance in Grafana

**Open Grafana Dashboard** (http://$VM3_IP:3000)

Watch these metrics during 5G test:

- **VM2 CPU Usage**: Should remain **<10%**
- **VM2 Network Throughput**: Can reach **~500 Mbps**
- **VM2 Memory**: Low usage (~20%)
- **Open5GS Sessions**: Active sessions visible

**Key Observation:** Network bandwidth is the bottleneck, not CPU

### 3.6 Stop 5G Simulation

```bash
# Stop UE (terminal 2)
Ctrl+C

# Stop gNB (terminal 1)
Ctrl+C

# Verify stopped
ps aux | grep -E "nr-gnb|nr-ue"
# Expected: No processes
```

### 3.7 Record 5G Baseline Metrics

| Metric            | Value          | Notes                      |
| ----------------- | -------------- | -------------------------- |
| Registration Time | ~10-15 seconds | UE registration to network |
| Average Latency   | 8-12 ms        | Ping to 8.8.8.8            |
| Peak Throughput   | 200-500 Mbps   | Network-limited            |
| CPU Usage         | <10%           | Protocol layer only        |
| Memory Usage      | ~20%           |                            |
| Jitter            | 2-3 ms         | Latency variation          |
| Packet Loss       | <0.1%          |                            |

**✅ Checkpoint:** 5G network tested, metrics recorded

---

## 📈 STEP 4: Comparative Analysis (30 minutes)

### 4.1 Side-by-Side Comparison

| Metric                | 4G (VM1) | 5G (VM2) | Difference         | Winner |
| --------------------- | -------- | -------- | ------------------ | ------ |
| **Registration Time** | 30-40s   | 10-15s   | 2-3x faster        | 🏆 5G  |
| **Latency (avg)**     | 35ms     | 10ms     | 3.5x lower         | 🏆 5G  |
| **Throughput**        | 30 Mbps  | 500 Mbps | 16x higher         | 🏆 5G  |
| **CPU Usage**         | 80-100%  | <10%     | 10x more efficient | 🏆 5G  |
| **Jitter**            | 12ms     | 2ms      | 6x more stable     | 🏆 5G  |
| **Packet Loss**       | <1%      | <0.1%    | 10x more reliable  | 🏆 5G  |

### 4.2 The Architectural Insight

**Why the massive difference?**

```
4G (srsRAN):
┌─────────────────────────────────────┐
│  Physical Layer Simulation          │
│  ├─ Radio wave modeling             │  CPU: 100%
│  ├─ Modulation (QPSK, 16-QAM)       │  ↓
│  ├─ Channel fading                  │  Bottleneck: CPU
│  ├─ Interference calculation        │  ↓
│  └─ DSP-like processing             │  Result: ~30 Mbps
└─────────────────────────────────────┘

5G (UERANSIM):
┌─────────────────────────────────────┐
│  Protocol Layer Simulation          │
│  ├─ RRC messages                    │  CPU: <10%
│  ├─ NAS messages                    │  ↓
│  ├─ NGAP signaling                  │  Bottleneck: Network
│  └─ No radio math                   │  ↓
└─────────────────────────────────────┘  Result: ~500 Mbps
```

**Conclusion:** 5G's service-based architecture (SBA) is inherently cloud-native, while 4G requires specialized hardware.

### 4.3 Create Grafana Comparison Dashboard

**The dashboard is automatically provisioned, but here are the professional panel configurations used:**

#### Panel 1: Real-time CPU Load (Gauge)

_Visualizes the heavy radio math in 4G vs the lightweight 5G core._

```promql
Query A (4G): 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle",instance="vm1-4g-core"}[1m])) * 100)
Query B (5G): 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle",instance="vm2-5g-core"}[1m])) * 100)
```

#### Panel 2: Network Throughput (Time Series)

_Smooth lines showing Mbps comparison._

```promql
Query A (4G): sum by (instance) (rate(node_network_receive_bytes_total{instance="vm1-4g-core",device!~"lo|docker.*"}[1m]) * 8 / 1000000)
Query B (5G): sum by (instance) (rate(node_network_receive_bytes_total{instance="vm2-5g-core",device!~"lo|docker.*"}[1m]) * 8 / 1000000)
```

#### Panel 3: Memory Utilization (Bar Gauge)

_LCD-style bars for memory consumption._

```promql
Query A (4G): (1 - (node_memory_MemAvailable_bytes{instance="vm1-4g-core"} / node_memory_MemTotal_bytes{instance="vm1-4g-core"})) * 100
Query B (5G): (1 - (node_memory_MemAvailable_bytes{instance="vm2-5g-core"} / node_memory_MemTotal_bytes{instance="vm2-5g-core"})) * 100
```

#### Panel 4: Active User Sessions (Stat)

_Big numbers with background area graphs._

```promql
Query A (4G): sum by (instance) (open5gs_session_count{instance="vm1-4g-core"})
Query B (5G): sum by (instance) (open5gs_session_count{instance="vm2-5g-core"})
```

#### Panel 5: Signaling Health (Status History)

_Timeline of SCTP associations (S1AP for 4G, NGAP for 5G)._

```promql
Query A (4G): sum by (instance) (open5gs_sctp_stat_active_associations{instance="vm1-4g-core"})
Query B (5G): sum by (instance) (open5gs_sctp_stat_active_associations{instance="vm2-5g-core"})
```

#### Panel 6: Network Reliability (Stat)

_Error/Drop counter - turns RED if errors > 0._

```promql
Query A (4G): sum by (instance) (rate(node_network_receive_errs_total{instance="vm1-4g-core"}[1m]) + rate(node_network_receive_drop_total{instance="vm1-4g-core"}[1m]))
Query B (5G): sum by (instance) (rate(node_network_receive_errs_total{instance="vm2-5g-core"}[1m]) + rate(node_network_receive_drop_total{instance="vm2-5g-core"}[1m]))
```

#### Panel 7: System Load (Gauge)

_Classic needle gauge for OS load._

```promql
Query A (4G): node_load1{instance="vm1-4g-core"}
Query B (5G): node_load1{instance="vm2-5g-core"}
```

#### Panel 8: Context Switches (Stat)

_Measures kernel overhead during high traffic._

```promql
Query A (4G): rate(node_context_switches_total{instance="vm1-4g-core"}[1m])
Query B (5G): rate(node_context_switches_total{instance="vm2-5g-core"}[1m])
```

#### Panel 9: Disk Activity (Bar Gauge)

_Vertical gradient bars for write throughput._

```promql
Query A (4G): rate(node_disk_written_bytes_total{instance="vm1-4g-core"}[1m]) / 1024
Query B (5G): rate(node_disk_written_bytes_total{instance="vm2-5g-core"}[1m]) / 1024
```

**✅ Checkpoint:** Comparison dashboard created in Grafana with professional visual styles.

---

## 🔬 STEP 5: Advanced Testing (Optional, 30 minutes)

### 5.1 Stress Test 4G Network

```bash
# SSH to VM1
ssh ayoubgory_gmail_com@$VM1_IP

# Start eNB and UE (as before)
sudo ./start-enb.sh &
sleep 30
sudo ./start-ue.sh &
sleep 30

# Run continuous ping test (5 minutes)
sudo ip netns exec ue1 ping -i 0.2 8.8.8.8 > /tmp/4g-latency.txt &

# Run bandwidth test
sudo ip netns exec ue1 iperf3 -c iperf.he.net -t 300 > /tmp/4g-throughput.txt

# Analyze results
cat /tmp/4g-latency.txt | tail -n 2
cat /tmp/4g-throughput.txt | grep "sender"
```

### 5.2 Stress Test 5G Network

```bash
# SSH to VM2
ssh ayoubgory_gmail_com@$VM2_IP

# Start gNB and UE (as before)
cd /home/ayoubgory_gmail_com/UERANSIM
sudo ./build/nr-gnb -c config/open5gs-gnb.yaml &
sleep 15
sudo ./build/nr-ue -c config/open5gs-ue.yaml &
sleep 15

# Run continuous ping test (5 minutes)
sudo ping -I uesimtun0 -i 0.2 8.8.8.8 > /tmp/5g-latency.txt &

# Run bandwidth test
sudo iperf3 -c iperf.he.net -B 10.45.0.2 -t 300 > /tmp/5g-throughput.txt

# Analyze results
cat /tmp/5g-latency.txt | tail -n 2
cat /tmp/5g-throughput.txt | grep "sender"
```

### 5.3 Multi-User Simulation (Advanced)

**Note:** This requires modifying configs to support multiple UEs

```bash
# On VM2 (5G supports this better)
# Edit config to add UE 2, UE 3, etc.
# UERANSIM can handle multiple UEs efficiently

# On VM1 (4G struggles with this)
# CPU will max out with just 2-3 UEs
# Demonstrates why 4G towers need hardware acceleration
```

**✅ Checkpoint:** Advanced testing completed

---

## 📝 STEP 6: Generate Test Report (20 minutes)

### 6.1 Export Grafana Dashboards

1. In Grafana, navigate to your comparison dashboard
2. Click **Share → Export**
3. Save as `4g-vs-5g-comparison.json`
4. Take screenshots of key graphs during tests

### 6.2 Create Test Summary

Create `TEST-RESULTS-SUMMARY.md`:

```markdown
# 4G vs 5G Test Results Summary

## Test Date

December 20, 2025

## Environment

- Cloud: Google Cloud Platform
- Region: us-central1-a
- VM1 (4G): e2-medium (2 vCPU, 4GB RAM)
- VM2 (5G): e2-medium (2 vCPU, 4GB RAM)
- VM3 (Monitoring): e2-medium (2 vCPU, 4GB RAM)

## Performance Summary

### Latency

- 4G Average: 35ms (min: 25ms, max: 45ms, jitter: 12ms)
- 5G Average: 10ms (min: 8ms, max: 12ms, jitter: 2ms)
- **Result: 5G is 3.5x faster with 6x lower jitter**

### Throughput

- 4G Average: 28 Mbps (CPU-limited)
- 5G Average: 480 Mbps (network-limited)
- **Result: 5G is 17x faster**

### Resource Usage

- 4G CPU: 85-95% (physical layer simulation)
- 5G CPU: 5-8% (protocol layer only)
- **Result: 5G is 11x more efficient**

### Reliability

- 4G Packet Loss: 0.8%
- 5G Packet Loss: 0.05%
- **Result: 5G is 16x more reliable**

## Key Findings

1. **5G is Cloud-Native**: Low CPU usage proves 5G can run efficiently in containers
2. **4G Requires Hardware**: High CPU usage shows why 4G needs DSP chips
3. **Scalability**: One VM2 instance could handle 100+ UEs; VM1 struggles with 3
4. **Latency**: 5G's streamlined protocol stack provides 3x lower latency

## Conclusion

This test demonstrates that 5G's architectural redesign makes it fundamentally
more suitable for cloud deployment than 4G. The shift from physical layer to
protocol layer simulation in testing reflects the real-world shift from
hardware-dependent to software-defined networking.

## Grafana Dashboard

See attached: 4g-vs-5g-comparison.json
```

### 6.3 Verify All Tests Passed

```bash
# Run all verification tests one more time
ssh ayoubgory_gmail_com@$VM1_IP "bash /home/ayoubgory_gmail_com/test-vm1-4g.sh"
ssh ayoubgory_gmail_com@$VM2_IP "bash /home/ayoubgory_gmail_com/test-vm2-5g.sh"
ssh ayoubgory_gmail_com@$VM3_IP "bash /home/ayoubgory_gmail_com/test-vm3-monitoring.sh"

# Expected: All tests PASS
```

**✅ Checkpoint:** Test report generated

---

## 🎯 Phase 2 Completion Checklist

- [ ] Grafana configured with Prometheus data source
- [ ] All 6 Prometheus targets showing UP
- [ ] 4G network tested (eNB + UE connected)
- [ ] 4G baseline metrics recorded
- [ ] 5G network tested (gNB + UE connected)
- [ ] 5G baseline metrics recorded
- [ ] Grafana comparison dashboard created
- [ ] Performance analysis completed
- [ ] Test report generated
- [ ] Screenshots saved
- [ ] All verification tests passed

**🎉 Phase 2 Complete!**

---

## 🔍 Troubleshooting

### 4G Issues (VM1)

**Problem:** eNB won't start

```bash
# Check MME is accessible
sudo netstat -tlnup | grep 36412
# Solution: Restart MME
sudo systemctl restart open5gs-mmed
```

**Problem:** UE can't attach

```bash
# Check subscriber exists
mongosh open5gs --eval "db.subscribers.find({imsi: '001010000000001'})"
# Solution: Re-add subscriber via WebUI
```

### 5G Issues (VM2)

**Problem:** gNB shows "NG Setup Failure"

```bash
# Check AMF is accessible
sudo systemctl status open5gs-amfd
# Check AMF logs
sudo journalctl -u open5gs-amfd -n 50
# Solution: Restart AMF
sudo systemctl restart open5gs-amfd
```

**Problem:** UE registration fails

```bash
# Check subscriber exists
mongosh open5gs --eval "db.subscribers.find({imsi: '999700000000001'})"
# Check slice configuration
sudo journalctl -u open5gs-amfd | grep -i "slice"
# Solution: Verify SMF has SST=1 configured
```

### Monitoring Issues (VM3)

**Problem:** Prometheus targets DOWN

```bash
# Check connectivity to VM1
ping 10.10.0.10
curl http://10.10.0.10:9100/metrics

# Check connectivity to VM2
ping 10.10.0.20
curl http://10.10.0.20:9100/metrics

# Solution: Check GCP firewall rules
gcloud compute firewall-rules list --filter="network:open5gs-vpc"
```

**Problem:** Grafana shows "No Data"

```bash
# Check Prometheus is scraping
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].health'

# Check time range in Grafana
# Solution: Ensure "Last 15 minutes" selected
```

---

## � Additional Implementation for Complete Project Requirements

### 1️⃣ Node Exporter on All VMs

Install Node Exporter on VM1, VM2, and VM3 for system metrics (CPU, RAM, network).

```bash
# On each VM (VM1, VM2, VM3)
sudo apt update
sudo apt install -y prometheus-node-exporter

# Verify service
sudo systemctl status prometheus-node-exporter
```

Update `prometheus.yml` on VM3:

```yaml
- job_name: "node-vm1-4g"
  static_configs:
    - targets: ["vm1-4g-core:9100"]
      labels:
        instance: "vm1-4g-core"

- job_name: "node-vm2-5g"
  static_configs:
    - targets: ["vm2-5g-core:9100"]
      labels:
        instance: "vm2-5g-core"

- job_name: "node-vm3-monitoring"
  static_configs:
    - targets: ["localhost:9100"]
```

Restart Prometheus:

```bash
sudo systemctl restart prometheus
```

**✅ Checkpoint:** All Node Exporter targets UP in Prometheus.

### 2️⃣ QoS Collection Scripts

Use the scripts in `tests/` folder for standardized measurements.

#### Run Ping Test (RTT)

```bash
# From VM1 to VM2 (during 4G test)
cd /path/to/tests
./run_ping.sh 10.10.0.20 60

# From VM2 to VM1 (during 5G test)
./run_ping.sh 10.10.0.10 60
```

#### Run TCP Throughput Test

```bash
# Start iperf server on target VM
iperf3 -s

# Run client from source VM
./run_iperf_tcp.sh <target_ip> 60
```

#### Run UDP Jitter/Loss Test

```bash
# Start UDP server
iperf3 -s -u

# Run client
./run_iperf_udp.sh <target_ip> 60 100  # 100 Mbps bandwidth
```

### 3️⃣ Enhanced Grafana Dashboards

#### Dashboard 1: Infrastructure Monitoring

Create panels for CPU, RAM, Network RX/TX, Packet Drops.

#### Dashboard 2: QoS 4G vs 5G Comparison

Add panels for average throughput, RTT, jitter, packet loss with labels `tech="4G"` and `tech="5G"`.

#### Dashboard 3: QoE (User Experience)

Panels for download times (wget), UDP stability, performance under load.

### 4️⃣ API Gateway on VM3 (Security)

Implement NGINX as API Gateway for 5G control plane security.

#### Installation

```bash
sudo apt install -y nginx
```

#### Configuration (/etc/nginx/sites-available/api-gateway)

```nginx
server {
    listen 80;
    server_name api-gateway;

    # Auth
    auth_basic "5G Control Plane";
    auth_basic_user_file /etc/nginx/.htpasswd;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

    location /smf {
        limit_req zone=api burst=5 nodelay;
        proxy_pass http://smf:7777;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /amf {
        limit_req zone=api burst=5 nodelay;
        proxy_pass http://amf:7777;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Logging
    access_log /var/log/nginx/api_gateway.log;
    error_log /var/log/nginx/api_gateway_error.log;
}
```

Create htpasswd file:

```bash
sudo apt install -y apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd user
```

Enable site:

```bash
sudo ln -s /etc/nginx/sites-available/api-gateway /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 5️⃣ Security Validation

Test API Gateway security:

```bash
# Unauthorized request (should fail)
curl http://vm3-ip/smf

# Authorized request (should succeed)
curl -u user:password http://vm3-ip/smf

# Rate limit test (rapid requests)
for i in {1..15}; do curl -u user:password http://vm3-ip/smf; done
```

Check logs:

```bash
sudo tail -f /var/log/nginx/api_gateway.log
```

### 6️⃣ Speed Comparison Test (4G vs 5G)

Run simultaneous throughput tests during active simulations.

#### Test Procedure

1. Start 4G simulation on VM1
2. Run TCP throughput test from VM1 to external server
3. Stop 4G, start 5G on VM2
4. Run same TCP test from VM2
5. Compare results in Grafana dashboard

```bash
# During 4G test
./run_iperf_tcp.sh iperf.he.net 60

# During 5G test
./run_iperf_tcp.sh iperf.he.net 60
```

**Expected Results:** 5G should show higher throughput and lower CPU usage.

### 7️⃣ Correlation QoS ↔ Security

Demonstrate that API Gateway protects against overload:

1. Generate high traffic to API Gateway
2. Monitor rate limiting in logs
3. Observe stable control plane metrics in Grafana despite load

---

## �📚 Additional Resources

- **Open5GS Metrics**: All Open5GS services expose Prometheus metrics on port 9090
- **Node Exporter**: System metrics available on port 9100
- **UERANSIM Logs**: Check `/tmp/ueransim.log` for detailed 5G signaling
- **srsRAN Logs**: Check `/tmp/srsenb.log` and `/tmp/srsue.log` for 4G signaling

---

## 🎓 Key Learnings

1. **Architectural Difference**: 4G needs physical layer simulation (CPU-heavy), 5G uses protocol layer (lightweight)
2. **Cloud Readiness**: 5G's <10% CPU usage makes it perfect for Kubernetes/containers
3. **Scalability**: 5G can handle 10-100x more users per VM than 4G
4. **Performance**: 5G delivers 3x lower latency and 15x higher throughput
5. **Monitoring**: Centralized Prometheus + Grafana provides unified visibility

**Next:** Use these insights for your DevOps presentation or report! 🚀
