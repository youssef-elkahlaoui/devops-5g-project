# Reset to Basic Open5GS Configuration

**Goal:** Get basic 5G SA connectivity working with simple PLMN 001/01, then proceed to benchmarking.

## Problem Analysis
- Complex network slicing (SST=1, SD=0x000001) causing registration failures
- Multiple NF configuration issues with localhost vs subnet addresses
- Authentication working but registration failing at final stages

## Solution: Reset to Basic Configuration
Use Open5GS default test PLMN **001/01** with **simple slice SST=1 (no SD)**.

---

## Step 1: Reset Open5GS Core to Basic Config

### 1.1 Basic NRF Configuration
**File:** `/etc/open5gs/nrf.yaml`

```yaml
logger:
  file:
    path: /var/log/open5gs/nrf.log

global:
  max:
    ue: 1024

nrf:
  serving:
    - plmn_id:
        mcc: 001
        mnc: 01
  sbi:
    server:
      - address: 10.10.0.2
        port: 7777
```

### 1.2 Basic AMF Configuration
**File:** `/etc/open5gs/amf.yaml`

```yaml
logger:
  file:
    path: /var/log/open5gs/amf.log

global:
  max:
    ue: 1024

amf:
  sbi:
    server:
      - address: 10.10.0.2
        port: 7778
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
        mcc: 001
        mnc: 01
      amf_id:
        region: 2
        set: 1

  tai:
    - plmn_id:
        mcc: 001
        mnc: 01
      tac: 1

  plmn_support:
    - plmn_id:
        mcc: 001
        mnc: 01
      s_nssai:
        - sst: 1

  security:
    integrity_order: [NIA2, NIA1, NIA0]
    ciphering_order: [NEA0, NEA1, NEA2]
```

### 1.3 Basic SMF Configuration
**File:** `/etc/open5gs/smf.yaml`

```yaml
logger:
  file:
    path: /var/log/open5gs/smf.log

global:
  max:
    ue: 1024

smf:
  sbi:
    server:
      - address: 10.10.0.2
        port: 7776
    client:
      nrf:
        - uri: http://10.10.0.2:7777

  pfcp:
    server:
      - address: 10.10.0.2

  gtpc:
    server:
      - address: 10.10.0.2

  gtpu:
    server:
      - address: 10.10.0.2

  metrics:
    server:
      - address: 10.10.0.2
        port: 9090

  session:
    - subnet: 10.45.0.0/16
      gateway: 10.45.0.1
      dnn: internet

  dns:
    - 8.8.8.8
    - 8.8.4.4
```

### 1.4 Basic UPF Configuration
**File:** `/etc/open5gs/upf.yaml`

```yaml
logger:
  file:
    path: /var/log/open5gs/upf.log

global:
  max:
    ue: 1024

upf:
  pfcp:
    server:
      - address: 10.11.0.7

  gtpu:
    server:
      - address: 10.11.0.7

  session:
    - subnet: 10.45.0.0/16
      gateway: 10.45.0.1
      dnn: internet
    - subnet: 2001:db8:cafe::/48
      gateway: 2001:db8:cafe::1
      dnn: internet

  metrics:
    server:
      - address: 10.11.0.7
        port: 9090
```

### 1.5 Keep Other NFs Simple (AUSF, UDM, UDR, PCF)
These are already configured correctly:
- AUSF: `10.10.0.2:7779`
- UDM: `10.10.0.2:7780`
- UDR: `10.10.0.2:7783` (with MongoDB)
- PCF: `10.10.0.2:7781`

---

## Step 2: Reset UERANSIM to Basic Config

### 2.1 Basic gNB Configuration
**File:** `/root/UERANSIM/config/open5gs-gnb.yaml`

```yaml
mcc: '001'
mnc: '01'
nci: '0x000000010'
idLength: 32
tac: 1
linkIp: 10.10.0.100
ngapIp: 10.10.0.100
gtpIp: 10.10.0.100

amfConfigs:
  - address: 10.10.0.2
    port: 38412

slices:
  - sst: 1

ignoreStreamIds: true
```

### 2.2 Basic UE Configuration
**File:** `/root/UERANSIM/config/open5gs-ue.yaml`

```yaml
supi: 'imsi-001010000000001'
mcc: '001'
mnc: '01'
routingIndicator: '0000'

key: '465B5CE8B199B49FAA5F0A2EE238A6BC'
op: 'E8ED289DEBA952E4283B54E88E6183CA'
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

configured-nssai:
  - sst: 1

default-nssai:
  - sst: 1
```

---

## Step 3: Update MongoDB Subscriber

Connect to MongoDB and update subscriber:

```bash
sudo mongo open5gs
```

```javascript
db.subscribers.updateOne(
  { imsi: "001010000000001" },
  {
    $set: {
      imsi: "001010000000001",
      subscribed_rau_tau_timer: 12,
      network_access_mode: 0,
      subscriber_status: 0,
      access_restriction_data: 32,
      slice: [
        {
          sst: 1,
          default_indicator: true,
          session: [
            {
              name: "internet",
              type: 3,
              pcc_rule: [],
              ambr: {
                downlink: { value: 1, unit: 3 },
                uplink: { value: 1, unit: 3 }
              },
              qos: {
                index: 9,
                arp: {
                  priority_level: 8,
                  pre_emption_capability: 1,
                  pre_emption_vulnerability: 1
                }
              }
            }
          ]
        }
      ],
      ambr: {
        downlink: { value: 1, unit: 3 },
        uplink: { value: 1, unit: 3 }
      },
      security: {
        k: "465B5CE8B199B49FAA5F0A2EE238A6BC",
        opc: "E8ED289DEBA952E4283B54E88E6183CA",
        amf: "8000",
        sqn: NumberLong("0")
      }
    }
  },
  { upsert: true }
);
```

Or delete old and insert new:

```javascript
db.subscribers.deleteOne({ imsi: "999700000000001" });
db.subscribers.insertOne({
  imsi: "001010000000001",
  security: {
    k: "465B5CE8B199B49FAA5F0A2EE238A6BC",
    opc: "E8ED289DEBA952E4283B54E88E6183CA",
    amf: "8000",
    sqn: NumberLong("0")
  },
  slice: [{
    sst: 1,
    default_indicator: true,
    session: [{
      name: "internet",
      type: 3,
      qos: { index: 9, arp: { priority_level: 8 } },
      ambr: { downlink: { value: 1, unit: 3 }, uplink: { value: 1, unit: 3 } }
    }]
  }],
  ambr: { downlink: { value: 1, unit: 3 }, uplink: { value: 1, unit: 3 } }
});
```

---

## Step 4: Setup IP Forwarding and NAT (on control VM)

```bash
# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

# Make permanent
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding=1' | sudo tee -a /etc/sysctl.conf

# Add NAT rules for ogstun interface
sudo iptables -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE
sudo ip6tables -t nat -A POSTROUTING -s 2001:db8:cafe::/48 ! -o ogstun -j MASQUERADE

# Accept packets on ogstun
sudo iptables -I INPUT -i ogstun -j ACCEPT

# Disable firewall if enabled
sudo ufw status
sudo ufw disable  # if active
```

---

## Step 5: Restart All Services

### On Control VM (10.10.0.2):

```bash
# Restart in order
sudo systemctl restart open5gs-nrfd
sleep 2
sudo systemctl restart open5gs-smfd
sudo systemctl restart open5gs-ausfd
sudo systemctl restart open5gs-udmd
sudo systemctl restart open5gs-udrd
sudo systemctl restart open5gs-pcfd
sleep 2
sudo systemctl restart open5gs-amfd
sleep 3

# Check all registered
sudo journalctl -u open5gs-nrfd -n 20 --no-pager | grep "NF registered"
```

### On UPF VM (10.11.0.7) - if separate:

```bash
sudo systemctl restart open5gs-upfd
sleep 3
sudo systemctl status open5gs-upfd
```

### On RAN VM (10.10.0.100):

```bash
cd /root/UERANSIM

# Kill old processes
sudo pkill -9 nr-gnb
sudo pkill -9 nr-ue

# Start gNB
sudo ./build/nr-gnb -c config/open5gs-gnb.yaml &
sleep 5

# Check gNB connected
# Should see: "NG Setup procedure is successful"
```

---

## Step 6: Test UE Registration

```bash
cd /root/UERANSIM
sudo ./build/nr-ue -c config/open5gs-ue.yaml
```

**Expected Success Output:**
```
[nas] [info] UE switches to state [MM-REGISTERED/NORMAL-SERVICE]
[nas] [info] PDU Session establishment is successful PSI[1]
[nas] [info] PDU Session address : 10.45.0.2
```

---

## Step 7: Verify Connectivity

### Check uesimtun0 interface:
```bash
ip addr show uesimtun0
```

**Expected:**
```
inet 10.45.0.2/16 scope global uesimtun0
```

### Test ping:
```bash
ping -I uesimtun0 -c 5 8.8.8.8
ping -I uesimtun0 -c 5 google.com
```

---

## Step 8: Move to Benchmarking

Once connectivity is verified, proceed with Phase 3 benchmarking tests:
- Throughput tests with iperf3
- Latency measurements
- Packet loss analysis
- Resource utilization monitoring

See [PHASE-3-VM-Monitoring.md](PHASE-3-VM-Monitoring.md) for detailed benchmarking procedures.

---

## Key Changes from Previous Config
1. **PLMN:** 999/70 → **001/01** (international test PLMN)
2. **Slice:** Removed SD (0x000001), using only **SST=1**
3. **IMSI:** 999700000000001 → **001010000000001**
4. **Subnet:** Changed to 10.45.0.0/16 (Open5GS default)
5. **Simplified:** No advanced slicing, basic DNN configuration

---

## Troubleshooting

### If UE fails to register:
1. Check AMF logs: `sudo journalctl -u open5gs-amfd -f`
2. Check gNB connected: Should see NGAP messages in AMF logs
3. Verify subscriber in MongoDB: `sudo mongo open5gs`
4. Check all NFs registered: `sudo journalctl -u open5gs-nrfd -n 20`

### If no uesimtun0 interface:
1. Check SMF logs: `sudo journalctl -u open5gs-smfd -f`
2. Check UPF logs: `sudo journalctl -u open5gs-upfd -f`
3. Verify ogstun interface on control VM: `ip addr show ogstun`
4. Check NAT rules: `sudo iptables -t nat -L -n -v`

### If ping fails:
1. Check IP forwarding: `sysctl net.ipv4.ip_forward`
2. Check NAT rules: `sudo iptables -t nat -L POSTROUTING -n -v`
3. Check firewall: `sudo ufw status`
4. Test DNS: `nslookup google.com`
