# Enterprise Collapsed Core (2-Tier Campus) Lab

## Overview

This lab demonstrates a **collapsed core** campus design — a 2-tier architecture
where the traditional core and distribution layers are merged into a single,
redundant switch pair. This is the standard choice for medium-sized campuses
(roughly 50–500 users) where the cost and complexity of a full 3-tier hierarchy
is not justified.

The lab is fully pre-configured and working out of the box. Deploy it, explore
the VRRP, STP, and OSPF behaviour, then run the demo tasks to observe failover.

---

## Topology

```
                       [isp]  AS65500
                         | 203.0.113.0/30  (.1=isp, .2=edge)
                       [edge] AS65100
                      /         \
          10.0.12.0/30           10.0.22.0/30
         (.1=edge,.2=cc1)      (.1=edge,.2=cc2)
              /                       \
           [cc1] ---10.0.99.0/30--- [cc2]
         STP root:               STP root:
         VLAN 10,30               VLAN 20
          /      \               /      \
       [acc1]  [acc2]        [acc3]  [acc4]
         |                     |
     [client-a]            [client-b]
      VLAN 10                VLAN 20
    10.10.10.11            10.20.20.11
```

### Node Summary

| Node     | Kind  | Role                          | AS    | Loopback    |
|----------|-------|-------------------------------|-------|-------------|
| isp      | cEOS  | Upstream ISP (eBGP peer)      | 65500 | 1.1.1.1/32  |
| edge     | cEOS  | Enterprise edge router        | 65100 | 10.0.0.2/32 |
| cc1      | cEOS  | Collapsed core #1 (L3+L2)    | —     | 10.0.0.3/32 |
| cc2      | cEOS  | Collapsed core #2 (L3+L2)    | —     | 10.0.0.4/32 |
| acc1     | cEOS  | Access switch (cc1 side)      | —     | —           |
| acc2     | cEOS  | Access switch (cc1 side)      | —     | —           |
| acc3     | cEOS  | Access switch (cc2 side)      | —     | —           |
| acc4     | cEOS  | Access switch (cc2 side)      | —     | —           |
| client-a | Linux | VLAN 10 corporate client      | —     | —           |
| client-b | Linux | VLAN 20 voice client          | —     | —           |

### Link Addressing

| Link               | Subnet           | Left       | Right      |
|--------------------|------------------|------------|------------|
| isp – edge         | 203.0.113.0/30   | .1 (isp)   | .2 (edge)  |
| edge – cc1         | 10.0.12.0/30     | .1 (edge)  | .2 (cc1)   |
| edge – cc2         | 10.0.22.0/30     | .1 (edge)  | .2 (cc2)   |
| cc1 – cc2          | 10.0.99.0/30     | .1 (cc1)   | .2 (cc2)   |
| cc1 – acc1         | trunk 10,20,30,99 | —         | —          |
| cc1 – acc2         | trunk 10,20,30,99 | —         | —          |
| cc2 – acc3         | trunk 10,20,30,99 | —         | —          |
| cc2 – acc4         | trunk 10,20,30,99 | —         | —          |
| acc1 – client-a    | VLAN 10 access   | —          | —          |
| acc3 – client-b    | VLAN 20 access   | —          | —          |

### VLAN Design

| VLAN | Name        | Subnet          | VRRP VIP     | cc1 Role | cc2 Role |
|------|-------------|-----------------|--------------|----------|----------|
| 10   | corporate   | 10.10.10.0/24   | 10.10.10.1   | ACTIVE   | standby  |
| 20   | voice       | 10.20.20.0/24   | 10.20.20.1   | standby  | ACTIVE   |
| 30   | guest       | 10.30.30.0/24   | 10.30.30.1   | ACTIVE   | standby  |
| 99   | management  | 192.168.99.0/24 | —            | .2       | .3       |

### STP Root Assignment (RSTP, per-VLAN priorities)

| VLAN | Root Bridge | Priority |
|------|-------------|----------|
| 10   | cc1         | 4096     |
| 20   | cc2         | 4096     |
| 30   | cc1         | 4096     |
| 99   | cc1 or cc2  | 32768    |

VRRP active and STP root are aligned per VLAN: traffic flows to the same
switch at both L2 and L3, avoiding asymmetric paths.

---

## Deploy

```bash
# Build the Linux client image first (if not already built)
docker build -t frr-lab:local images/frr/

# Make setup scripts executable
chmod +x labs/enterprise-collapsed-core/configs/client-a/setup.sh
chmod +x labs/enterprise-collapsed-core/configs/client-b/setup.sh

# Deploy
sudo containerlab deploy -t labs/enterprise-collapsed-core/topology.clab.yml

# Or with the helper script
./scripts/lab.sh deploy enterprise-collapsed-core
```

## Destroy

```bash
sudo containerlab destroy -t labs/enterprise-collapsed-core/topology.clab.yml --cleanup
./scripts/lab.sh destroy enterprise-collapsed-core
```

---

## Verification Commands

### Access Nodes

```bash
# cEOS nodes
docker exec -it clab-enterprise-collapsed-core-cc1   Cli
docker exec -it clab-enterprise-collapsed-core-cc2   Cli
docker exec -it clab-enterprise-collapsed-core-edge  Cli
docker exec -it clab-enterprise-collapsed-core-acc1  Cli

# Linux clients
docker exec -it clab-enterprise-collapsed-core-client-a bash
docker exec -it clab-enterprise-collapsed-core-client-b bash
```

### Routing — Edge

```bash
# On edge: verify BGP session to ISP, default route received
show bgp summary
show bgp ipv4 unicast
show ip route

# OSPF neighbors (cc1 and cc2 should appear)
show ip ospf neighbor
show ip ospf database
```

### Routing — Collapsed Core

```bash
# On cc1 or cc2: OSPF adjacencies to edge and each other
show ip ospf neighbor

# Routing table — should see 0.0.0.0/0 via OSPF (from edge)
show ip route
show ip route ospf

# Inter-VLAN routes should be in the table (directly connected SVIs)
show ip interface brief
```

### VRRP State

```bash
# On cc1 — expect: VLAN 10 MASTER, VLAN 20 BACKUP, VLAN 30 MASTER
show vrrp

# On cc2 — expect: VLAN 10 BACKUP, VLAN 20 MASTER, VLAN 30 BACKUP
show vrrp

# Detail for a specific group
show vrrp detail
```

### STP

```bash
# On cc1: root for VLAN 10 and 30
show spanning-tree vlan 10
show spanning-tree vlan 20
show spanning-tree vlan 30

# On acc1: upstream port should be designated/root toward cc1
show spanning-tree

# Check BPDU statistics
show spanning-tree detail
```

### End-to-End Connectivity

```bash
# From client-a: ping the VRRP gateway
docker exec clab-enterprise-collapsed-core-client-a ping -c3 10.10.10.1

# From client-a: ping across to VLAN 20 subnet (inter-VLAN routing via cc1/cc2)
docker exec clab-enterprise-collapsed-core-client-a ping -c3 10.20.20.11

# From client-a: ping toward the ISP loopback (tests full default route path)
docker exec clab-enterprise-collapsed-core-client-a ping -c3 1.1.1.1

# From client-b: ping its gateway (VRRP VIP on cc2)
docker exec clab-enterprise-collapsed-core-client-b ping -c3 10.20.20.1
docker exec clab-enterprise-collapsed-core-client-b ping -c3 10.10.10.11
docker exec clab-enterprise-collapsed-core-client-b ping -c3 1.1.1.1
```

### Traceroute — Normal Path

```bash
# client-a -> 1.1.1.1 should traverse: cc1 (VRRP active) -> edge -> isp
docker exec clab-enterprise-collapsed-core-client-a traceroute -n 1.1.1.1
```

Expected hops:
1. 10.10.10.1 — cc1 VRRP VIP (also cc1 SVI IP 10.10.10.2)
2. 10.0.12.1 — edge (cc1→edge link)
3. 203.0.113.1 — isp

---

## Demo Tasks

### Task 1 — VRRP Failover (cc1 shutdown)

Simulate a complete cc1 failure and observe client-a losing its active gateway
then switching to cc2.

**Step 1**: watch VRRP state on cc2 before failure:
```bash
# On cc2
watch show vrrp
```

**Step 2**: watch client-a connectivity in another terminal:
```bash
# Continuous ping from client-a
docker exec clab-enterprise-collapsed-core-client-a ping 10.10.10.1
```

**Step 3**: shut cc1 down:
```bash
docker stop clab-enterprise-collapsed-core-cc1
```

**Expected observations**:
- cc2 transitions VLAN 10 VRRP group from BACKUP to MASTER (after 3 x 1 second
  advertisement interval = ~3 second dead interval)
- client-a pings resume using cc2 as gateway
- OSPF on edge loses cc1 neighbor; the 10.10.10.0/24 and 10.0.12.0/30 routes
  remain reachable via cc2 (cc2 also advertises those VLAN subnets)
- STP re-elects a root on VLANs 10 and 30: cc2 becomes root with default
  priority 32768

**Step 4**: restore cc1:
```bash
docker start clab-enterprise-collapsed-core-cc1
```

cc1 rejoins OSPF and VRRP. Since cc1 has priority 120 vs cc2 fallback 100,
cc1 preempts and reclaims MASTER on VLAN 10 and 30 (preempt is enabled).

---

### Task 2 — Observe VRRP Advertisement Interval

```bash
# On client-a, run tcpdump to capture VRRP hellos on eth1
docker exec clab-enterprise-collapsed-core-client-a \
  tcpdump -i eth1 -n vrrp

# You should see periodic VRRP advertisements from the active router's real IP
# (10.10.10.2 from cc1 for group 10).
# Multicast destination: 224.0.0.18  Protocol: 112
```

---

### Task 3 — STP Topology Change Observation

```bash
# On acc1, check which port is the root port (upstream toward cc1)
docker exec clab-enterprise-collapsed-core-acc1 Cli -c "show spanning-tree vlan 10"

# Now shutdown the cc1-side uplink on acc1 (Ethernet1)
docker exec clab-enterprise-collapsed-core-acc1 Cli -c \
  "enable; configure; interface Ethernet1; shutdown"

# acc1 has no other uplink in this lab — it becomes isolated.
# In a real design you would dual-home acc1 to BOTH cc1 and cc2 (two uplinks),
# then blocking one via STP and failing over when the active link fails.
# This is the typical recommended design for access switches.

# Restore
docker exec clab-enterprise-collapsed-core-acc1 Cli -c \
  "enable; configure; interface Ethernet1; no shutdown"
```

---

### Task 4 — Trace the Default Route Through the Network

Understand how 0.0.0.0/0 flows from ISP all the way to the clients.

```bash
# On isp: what is being advertised?
docker exec clab-enterprise-collapsed-core-isp Cli -c "show bgp ipv4 unicast"

# On edge: BGP table shows 0.0.0.0/0 received from ISP
docker exec clab-enterprise-collapsed-core-edge Cli -c "show ip route 0.0.0.0/0"
# OSPF redistributes it via "default-information originate always"

# On cc1: OSPF-learned default route
docker exec clab-enterprise-collapsed-core-cc1 Cli -c "show ip route 0.0.0.0/0"

# On client-a: Linux routing table shows it too
docker exec clab-enterprise-collapsed-core-client-a ip route
```

---

### Task 5 — Add a VLAN 30 Guest Client (Extension Exercise)

Practice adding a client to the guest network without disrupting production VLANs.

The VLAN 30 SVI already exists on cc1 (10.30.30.2/24) and cc2 (10.30.30.3/24)
with VRRP VIP 10.30.30.1. To add a client:

1. Edit `topology.clab.yml` — add a `client-c` Linux node and link it to acc2:eth2.
2. Create `configs/client-c/setup.sh` with IP 10.30.30.11/24, gateway 10.30.30.1.
3. On acc2: `interface Ethernet2 / switchport access vlan 30 / switchport mode access`.
4. Redeploy or reconfigure acc2 manually via `Cli`.

---

## Design Rationale: 2-Tier vs 3-Tier

### Traditional 3-Tier Campus

```
                    [Core layer]
                   /            \
        [Distribution 1]   [Distribution 2]
         /    \                 /    \
      [Acc]  [Acc]          [Acc]  [Acc]
```

- Core: pure IP forwarding at high speed; no policy, no VLANs
- Distribution: L3 boundary, VLAN termination, policy (ACLs, QoS)
- Access: L2 only, VLAN assignment

### Collapsed Core (2-Tier) — This Lab

```
               [Collapsed Core pair]
              (core + distribution merged)
             /     |           |     \
          [Acc]  [Acc]      [Acc]  [Acc]
```

The core and distribution functions run on the same physical switch pair.

### When to Use Each Design

| Factor                  | Collapsed Core (2-Tier)     | 3-Tier                          |
|-------------------------|-----------------------------|---------------------------------|
| Campus size             | 50–500 users                | 500+ users / multiple buildings |
| Switch count            | 2 core + N access           | 2 core + 4–8 dist + N access    |
| CapEx                   | Lower (fewer boxes)         | Higher                          |
| Scale-out               | Limited (CC pair can bottleneck) | Easier horizontal expansion |
| STP domain              | Flatter, easier to reason about | Hierarchical, more complex  |
| Uplink bandwidth        | CC→Access: 10G common       | Dist→Access: 10G / Dist→Core: 40/100G |
| Failure blast radius    | Losing one CC = half campus loses redundancy | Losing one Dist = fewer users affected |
| Operational simplicity  | High                        | Moderate                        |

### Key Design Choices Demonstrated in This Lab

**VRRP + STP alignment**: cc1 is both the STP root AND the VRRP active router
for VLAN 10 and 30. cc2 owns VLAN 20. This ensures that L2 and L3 traffic
take the same physical path, avoiding suboptimal routing through the CC interlink.

**cc interlink (10.0.99.0/30)**: L3 routed link between cc1 and cc2. Used for:
- OSPF adjacency (backup path to edge if one CC-edge link fails)
- VRRP multicast advertisement exchange
- Forwarding inter-VLAN traffic if one CC loses its edge uplink

**passive-interface default + no passive on routed links**: OSPF hellos only on
the explicit L3 links (CC-edge and CC-CC interlink), not on VLAN SVIs. This
prevents client devices from forming OSPF adjacencies and reduces unnecessary
multicast traffic in the VLAN segments.

**default-information originate always**: The edge injects a default route into
OSPF even if its own RIB does not have one (useful during BGP convergence after
a restart). Without `always`, if the ISP BGP session goes down, the default
disappears from OSPF and the campus loses internet access.
