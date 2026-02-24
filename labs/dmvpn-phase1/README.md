# Lab: dmvpn-phase1

## Purpose
Learn DMVPN (Dynamic Multipoint VPN) Phase 1 — a scalable hub-and-spoke VPN that uses
mGRE (Multipoint GRE) and NHRP (Next Hop Resolution Protocol) to dynamically establish
tunnels. Understand how spokes register with the hub, how OSPF runs over the DMVPN tunnel,
and why DMVPN Phase 1 traffic always traverses the hub.

## Topology

```
         [spoke1] (172.16.0.11)
         /   WAN: 10.0.0.11
        /
[hub] (172.16.0.1) ---- [br-wan] ---- [spoke2] (172.16.0.12)
WAN: 10.0.0.1                          WAN: 10.0.0.12
        \
         \
         [spoke3] (172.16.0.13)
         WAN: 10.0.0.13
```

| Node | WAN IP | DMVPN tunnel IP | Simulated LAN |
|------|--------|-----------------|---------------|
| hub | 10.0.0.1/24 | 172.16.0.1/24 | — |
| spoke1 | 10.0.0.11/24 | 172.16.0.11/24 | 192.168.1.1/24 (lo) |
| spoke2 | 10.0.0.12/24 | 172.16.0.12/24 | 192.168.2.1/24 (lo) |
| spoke3 | 10.0.0.13/24 | 172.16.0.13/24 | 192.168.3.1/24 (lo) |

## Deploy / Destroy

```bash
sudo containerlab deploy -t topology.yml
sudo containerlab destroy -t topology.yml
```

## What Is Pre-Configured

The `setup.sh` scripts on each node configure:
- WAN interface IP (eth1) on the shared WAN bridge
- **mGRE tunnel (dmvpn0)** on hub — accepts tunnels from any spoke
- **GRE tunnel (dmvpn0)** on each spoke — points to hub as remote
- Tunnel IP addresses (172.16.0.x/24)
- Simulated LAN loopbacks on spokes (192.168.x.1/24)

After deploy, the GRE/mGRE interfaces exist. Your task is to configure NHRP and OSPF.

## What You Configure

### Step 1: Configure NHRP on the hub

```bash
docker exec -it clab-dmvpn-phase1-hub vtysh
configure terminal

interface dmvpn0
 ip nhrp network-id 1
 ip nhrp holdtime 300
 ip nhrp redirect
 ip ospf network point-to-multipoint
 ip ospf area 0

router ospf
 ospf router-id 10.0.0.1
 passive-interface lo
 network 172.16.0.0/24 area 0
 network 10.0.0.1/32 area 0

end
write memory
```

### Step 2: Configure NHRP on spoke1

```bash
docker exec -it clab-dmvpn-phase1-spoke1 vtysh
configure terminal

interface dmvpn0
 ip nhrp network-id 1
 ip nhrp holdtime 300
 ip nhrp nhs 172.16.0.1 nbma 10.0.0.1 multicast
 ip nhrp map 172.16.0.1 10.0.0.1
 ip nhrp registration no-unique
 ip ospf network point-to-point
 ip ospf area 0

router ospf
 ospf router-id 10.0.0.11
 passive-interface lo
 network 172.16.0.0/24 area 0
 network 10.0.0.11/32 area 0
 network 192.168.1.0/24 area 0

end
write memory
```

### Step 3: Configure NHRP on spoke2 and spoke3

Same as spoke1, adjusting router-id and LAN network:

**spoke2** (router-id 10.0.0.12, LAN 192.168.2.0/24):
```
interface dmvpn0
 ip nhrp network-id 1
 ip nhrp holdtime 300
 ip nhrp nhs 172.16.0.1 nbma 10.0.0.1 multicast
 ip nhrp map 172.16.0.1 10.0.0.1
 ip nhrp registration no-unique
 ip ospf network point-to-point
 ip ospf area 0

router ospf
 ospf router-id 10.0.0.12
 passive-interface lo
 network 172.16.0.0/24 area 0
 network 10.0.0.12/32 area 0
 network 192.168.2.0/24 area 0
```

**spoke3** (router-id 10.0.0.13, LAN 192.168.3.0/24) — same pattern.

### Step 4: Verify

```bash
# Check NHRP registrations on hub
docker exec clab-dmvpn-phase1-hub vtysh -c "show ip nhrp"

# Check OSPF neighbors (hub should see all 3 spokes)
docker exec clab-dmvpn-phase1-hub vtysh -c "show ip ospf neighbor"

# Check routes on spoke1 (should see 192.168.2.0/24 and 192.168.3.0/24 via hub)
docker exec clab-dmvpn-phase1-spoke1 vtysh -c "show ip route ospf"

# Ping from spoke1 to spoke2 LAN (goes via hub in Phase 1)
docker exec clab-dmvpn-phase1-spoke1 ping -c3 192.168.2.1
```

## Verification Commands

```
# NHRP
show ip nhrp                      # all registrations and mappings
show ip nhrp summary              # count of NHRP entries
show dmvpn                        # DMVPN summary (if available)

# OSPF
show ip ospf neighbor             # adjacency state
show ip ospf interface dmvpn0     # OSPF interface state and DR/BDR
show ip route ospf                # OSPF-learned routes

# GRE tunnel
ip tunnel show                    # tunnel interface details
ip link show dmvpn0               # link state

# Traffic path (Phase 1 — all through hub)
traceroute 192.168.2.1 source 192.168.1.1
```

## Concepts

### DMVPN Components

**mGRE (Multipoint GRE)** — A single GRE interface on the hub that can accept tunnels
from any spoke. The hub doesn't need a separate tunnel interface per spoke. Spokes use
regular GRE with the hub as the fixed remote endpoint.

**NHRP (Next Hop Resolution Protocol, RFC 2332)** — A protocol that maps overlay IP
addresses (tunnel IPs) to underlay IP addresses (physical WAN IPs). It's analogous to
ARP but for the tunnel overlay:

```
"What is the WAN IP for DMVPN IP 172.16.0.11?"
→ NHRP query to NHS (hub at 172.16.0.1)
← NHRP reply: 172.16.0.11 maps to 10.0.0.11
```

The hub is the **NHS (Next Hop Server)**. Spokes register themselves: "I am 172.16.0.11
and my WAN (NBMA) address is 10.0.0.11."

### Phase 1 vs Phase 2 vs Phase 3

**Phase 1** (this lab): Hub-and-spoke only. All spoke-to-spoke traffic goes through the
hub. Simple to configure but hub is a bottleneck.

**Phase 2**: Spokes can resolve each other's WAN IPs via NHRP and create direct
spoke-to-spoke tunnels. Requires nhrp shortcut on spokes.

**Phase 3**: Dynamic routing protocols aware of DMVPN shortcuts (NHRP route injection).
Most scalable.

### OSPF Network Types over DMVPN

Hub must use `point-to-multipoint` because it has multiple OSPF neighbors on one interface:
- DR/BDR election is skipped
- Each neighbor gets a host route in the OSPF LSDB

Spokes use `point-to-point` because they only have one neighbor (hub) on dmvpn0.

### NHRP Network-ID

The `ip nhrp network-id 1` must match on hub and all spokes. It groups all DMVPN
participants into the same NHRP domain.

## Challenge Exercises

1. Capture the NHRP registration packets: `tcpdump -i eth1 port 4791` on hub (or
   use Wireshark). Observe the NHRP Registration Request from a spoke and the Reply.

2. Verify Phase 1 behavior: use `traceroute 192.168.2.1 source 192.168.1.1` from
   spoke1. How many hops are there? Why does traffic go through hub?

3. Break NHRP by changing the network-id on one spoke. What happens to OSPF adjacency?
   Can OSPF still form without NHRP?

4. Add authentication to NHRP: `ip nhrp authentication SECRETKEY` (must match on all
   nodes). What happens if spoke3 uses a different key?

5. Try Phase 2: add `ip nhrp shortcut` on the spoke interfaces and `ip nhrp redirect`
   on hub. After spoke1 pings spoke2, check `show ip nhrp` on spoke1 — do you see a
   direct NHRP mapping for spoke2's WAN IP?
