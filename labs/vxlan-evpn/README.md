# Lab: vxlan-evpn

## Purpose
Learn VXLAN with BGP EVPN control plane — the standard for modern data center overlay
networks. Understand how BGP EVPN distributes MAC/IP reachability (type-2 routes) and
BUM membership (type-3 IMET routes), eliminating data-plane flooding in VXLAN fabrics.
Observe how the control plane drives forwarding table population instead of traditional
MAC learning.

This is a **fully configured reference lab**. Deploy it and explore the working EVPN
control plane.

## Topology

```
[host1]---eth1---[vtep1]---eth1---[spine/RR]---eth2---[vtep2]---eth2---[host2]
172.16.0.1/24    VTEP              BGP RR             VTEP         172.16.0.2/24
                 10.0.0.1                             10.0.0.2
                  |<--------- VXLAN VNI 100 (UDP 4789) ---------->|
                  |<--------- BGP EVPN control plane ------------>|
```

### Underlay

| Link | Subnet | VTEP | Spine |
|------|--------|------|-------|
| vtep1:eth1 -- spine:eth1 | 10.1.1.0/30 | .1 | .2 |
| vtep2:eth1 -- spine:eth2 | 10.1.2.0/30 | .1 | .2 |

Loopbacks (also VTEP IPs): spine=10.0.0.100, vtep1=10.0.0.1, vtep2=10.0.0.2

### Overlay

- VNI 100 — single L2 segment (VLAN-like)
- host1: 172.16.0.1/24 on eth1 (enslaved to br100 on vtep1)
- host2: 172.16.0.2/24 on eth1 (enslaved to br100 on vtep2)

## Deploy / Destroy

```bash
sudo containerlab deploy -t topology.yml
# Allow 30 seconds for OSPF and BGP EVPN to converge

sudo containerlab destroy -t topology.yml --cleanup
```

## How It Works

### Layer 1: OSPF Underlay
OSPF runs between vtep1–spine–vtep2. This gives every node reachability to every other
node's loopback IP. The VTEP loopbacks (10.0.0.1 and 10.0.0.2) serve as the VXLAN
tunnel endpoints.

### Layer 2: BGP EVPN Control Plane
iBGP sessions (AS65000) run between each VTEP and the spine Route Reflector. The RR
reflects routes between VTEPs without needing a full mesh.

VTEPs use `advertise-all-vni` which tells FRR to discover all locally configured VNIs
(vxlan100 in this case) and participate in EVPN for them.

### Layer 3: VXLAN Data Plane
`vxlan100` interfaces on both VTEPs are configured with `nolearning` — they do **not**
learn MAC addresses from data-plane traffic. Instead, BGP EVPN populates the kernel
VXLAN forwarding database via type-2 (MAC/IP) routes.

When host1 sends traffic to host2:
1. ARP from host1 triggers EVPN type-3 (IMET) BUM handling — replicated to vtep2
2. vtep2 receives the ARP, vtep1 and vtep2 exchange type-2 MAC/IP routes via RR
3. Subsequent unicast traffic goes directly vtep1 → vtep2 (no flooding)

## Verification Steps

### Step 1: Verify OSPF underlay

```bash
# OSPF neighbors (vtep1 should see spine)
docker exec clab-vxlan-evpn-vtep1 vtysh -c "show ip ospf neighbor"

# OSPF routes (vtep1 should have route to 10.0.0.2 via spine)
docker exec clab-vxlan-evpn-vtep1 vtysh -c "show ip route ospf"
```

### Step 2: Verify BGP EVPN sessions

```bash
# Session state (should show spine 10.0.0.100 as Established)
docker exec clab-vxlan-evpn-vtep1 vtysh -c "show bgp l2vpn evpn summary"
```

### Step 3: Check initial EVPN state (before ping)

```bash
# Should show type-3 (IMET) routes from each VTEP — these are the flood lists
docker exec clab-vxlan-evpn-vtep1 vtysh -c "show bgp l2vpn evpn"
```

### Step 4: Trigger MAC learning via ping

```bash
docker exec clab-vxlan-evpn-host1 ping -c3 172.16.0.2
```

### Step 5: Examine EVPN routes AFTER ping

```bash
# Should now include type-2 (MAC/IP) routes for both hosts
docker exec clab-vxlan-evpn-vtep1 vtysh -c "show bgp l2vpn evpn"

# Detailed view of a specific type-2 route
docker exec clab-vxlan-evpn-vtep1 vtysh -c "show bgp l2vpn evpn route type macip"
```

### Step 6: Verify VXLAN forwarding table

```bash
# host2's MAC should appear with dst 10.0.0.2 (vtep2's VTEP IP)
docker exec clab-vxlan-evpn-vtep1 bridge fdb show dev vxlan100

# Kernel VXLAN details
docker exec clab-vxlan-evpn-vtep1 ip -d link show vxlan100
```

### Step 7: Confirm VXLAN encapsulation with tcpdump

```bash
# On vtep1's underlay interface — should see VXLAN/UDP packets
docker exec clab-vxlan-evpn-vtep1 tcpdump -i eth1 -n udp port 4789 -c5
```

## Verification Commands

```
# OSPF
show ip ospf neighbor              # adjacency state
show ip route ospf                 # underlay routes

# BGP EVPN
show bgp l2vpn evpn summary        # session state
show bgp l2vpn evpn                # all EVPN routes (type-2, type-3)
show bgp l2vpn evpn route type macip    # type-2 MAC/IP routes only
show bgp l2vpn evpn route type multicast  # type-3 IMET routes only
show bgp l2vpn evpn vni            # VNI table

# VXLAN / Linux bridge
bridge fdb show dev vxlan100       # VXLAN forwarding database
bridge fdb show br br100           # bridge forwarding database
ip -d link show vxlan100           # VXLAN interface details

# End-to-end
ping 172.16.0.2 (from host1)
```

## Concepts

### VXLAN Encapsulation

VXLAN (Virtual eXtensible LAN, RFC 7348) wraps L2 Ethernet frames in UDP packets:

```
Outer Ethernet | Outer IP (VTEP→VTEP) | UDP (port 4789) | VXLAN header (VNI) | Inner Ethernet frame
```

The VNI (VXLAN Network Identifier) is 24 bits, supporting 16 million overlay segments
(compared to 4094 VLANs).

### BGP EVPN Route Types

| Type | Name | Purpose |
|------|------|---------|
| 1 | Ethernet Auto-Discovery | Multi-homing fast convergence |
| 2 | MAC/IP Advertisement | Distributes MAC+IP bindings |
| 3 | Inclusive Multicast (IMET) | BUM (flood) list membership |
| 4 | Ethernet Segment | Multi-homing designated forwarder |
| 5 | IP Prefix | L3 routing (inter-subnet) |

This lab primarily uses **type-2** (MAC/IP learning) and **type-3** (IMET flood lists).

### nolearning and Control-Plane MAC Learning

With `nolearning` on the VXLAN interface, the kernel does not populate the VXLAN FDB
from data-plane traffic. Instead, FRR's EVPN control plane populates it:
- When a host sends traffic, the local VTEP learns the MAC and sends an EVPN type-2 route
- The remote VTEP receives the type-2 route (via RR) and programs the kernel FDB

This eliminates flooding and provides consistent, loop-free MAC distribution.

### Route Reflector

The spine acts as a BGP RR for the L2VPN EVPN AF. Without a full mesh of iBGP sessions,
VTEPs only need one session (to the RR) to exchange EVPN routes with all other VTEPs.
The spine uses `route-reflector-client` on each VTEP neighbor.

### VTEP IP = Loopback IP

VXLAN tunnels use `local 10.0.0.x` (the loopback) as the source IP for VXLAN UDP packets.
This is why OSPF underlay reachability to loopbacks is essential — without it, VXLAN
tunnels cannot form.

## Challenge Exercises

1. Add a third VTEP node (vtep3, loopback 10.0.0.3, connected to spine:eth3) with
   host3 (172.16.0.3/24). Verify host1 can ping host3 without reconfiguring vtep1.

2. Use `tcpdump -i eth1 -w /tmp/capture.pcap` on vtep1 and copy the file out to observe
   VXLAN encapsulation in Wireshark: `docker cp clab-vxlan-evpn-vtep1:/tmp/capture.pcap .`

3. Add a second VNI (vxlan200 with VNI 200) on both VTEPs. Create host4 on VNI 200 and
   verify hosts on VNI 100 and VNI 200 cannot communicate (L2 isolation).

4. Observe the EVPN type-3 (IMET) routes before the first ping. What do they contain?
   Why are they needed even before any hosts have communicated?

5. Temporarily stop OSPF on vtep2 (`no router ospf`). What happens to the BGP EVPN
   session? Why does the BGP session fail when OSPF goes down?
