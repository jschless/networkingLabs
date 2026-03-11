# Lab: vxlan-evpn

## Scenario

You're the network engineer for **Acme Corp's** new data center. The DC hosts two tenants
that must be **completely isolated** from each other at all times, even though they share
the same physical switching infrastructure.

You'll build the full data center overlay fabric from scratch:
- **Underlay**: eBGP CLOS fabric for loopback (VTEP) reachability
- **Overlay**: BGP EVPN control plane distributing MAC/IP and prefix routes
- **Data plane**: VXLAN tunnels carrying tenant traffic between leaf VTEPs
- **Segmentation**: Separate VRFs per tenant, enforced by EVPN route-targets

When complete you will validate that Tenant-A hosts can reach each other across the
fabric, Tenant-B hosts can reach each other, and that no cross-tenant traffic is possible.

## Topology

```
                  [spine1]              [spine2]
                  AS65100               AS65200
              Lo:10.0.0.101         Lo:10.0.0.102
             /    /    \    \      /    /    \    \
           e1   e2   e3   e4   e1   e2   e3   e4
       [leaf1] [leaf2] [leaf3] [leaf4]
       AS65001 AS65002 AS65003 AS65004
       Lo:.1   Lo:.2   Lo:.3   Lo:.4
          |       |       |       |
      [host-a1][host-b1][host-a2][host-b2]
      VLAN 10  VLAN 20  VLAN 10  VLAN 20
      TENANT-A TENANT-B TENANT-A TENANT-B
   10.10.10.11 10.20.20.11 10.10.10.12 10.20.20.12
```

### Underlay links (all /31)

| Link | Subnet | Leaf IP | Spine IP |
|------|--------|---------|----------|
| leaf1 ↔ spine1 | 10.1.0.0/31 | .0 | .1 |
| leaf2 ↔ spine1 | 10.1.0.2/31 | .2 | .3 |
| leaf3 ↔ spine1 | 10.1.0.4/31 | .4 | .5 |
| leaf4 ↔ spine1 | 10.1.0.6/31 | .6 | .7 |
| leaf1 ↔ spine2 | 10.2.0.0/31 | .0 | .1 |
| leaf2 ↔ spine2 | 10.2.0.2/31 | .2 | .3 |
| leaf3 ↔ spine2 | 10.2.0.4/31 | .4 | .5 |
| leaf4 ↔ spine2 | 10.2.0.6/31 | .6 | .7 |

### Overlay services

| Tenant | VLAN | L2VNI | L3VNI | Subnet | Gateway (anycast) |
|--------|------|-------|-------|--------|-------------------|
| TENANT-A | 10 | 10010 | 50001 | 10.10.10.0/24 | 10.10.10.1 |
| TENANT-B | 20 | 10020 | 50002 | 10.20.20.0/24 | 10.20.20.1 |

### Hosts

| Host | Leaf | Tenant | IP |
|------|------|--------|----|
| host-a1 | leaf1 eth3 | TENANT-A | 10.10.10.11/24 |
| host-b1 | leaf2 eth3 | TENANT-B | 10.20.20.11/24 |
| host-a2 | leaf3 eth3 | TENANT-A | 10.10.10.12/24 |
| host-b2 | leaf4 eth3 | TENANT-B | 10.20.20.12/24 |

## Deploy / Destroy

```bash
sudo containerlab deploy -t topology.clab.yml
sudo containerlab destroy -t topology.clab.yml --cleanup
```

Allow ~60 seconds after deploy for EOS to boot and BGP to converge before testing.

## Access

```bash
# Leaves and spines
docker exec -it clab-vxlan-evpn-leaf1 Cli
docker exec -it clab-vxlan-evpn-spine1 Cli

# Hosts (to run pings)
docker exec -it clab-vxlan-evpn-host-a1 Cli
docker exec -it clab-vxlan-evpn-host-b1 Cli
```

---

## What's Pre-Configured

- All Ethernet and loopback **IP addresses** on leaves and spines
- **Spines** are fully configured (underlay eBGP + EVPN next-hop-unchanged)
- **Hosts** are fully configured (IP address + default route)

You configure everything on the **four leaf switches**.

---

## Tasks

Work through these in order on **all four leaves**. The complete reference config for
leaf1 is in `configs/leaf1/startup-config` as comments. Adapt the per-leaf values
(AS, router-id, neighbor IPs, RDs) shown in each leaf's startup-config.

### Task 1 — Create VRF instances

```
conf
vrf instance TENANT-A
vrf instance TENANT-B
ip routing vrf TENANT-A
ip routing vrf TENANT-B
```

### Task 2 — Set the anycast gateway MAC

All leaves must use the **same** virtual MAC so hosts see a consistent gateway MAC
regardless of which leaf they're attached to.

```
ip virtual-router mac-address 00:1c:73:aa:aa:aa
```

### Task 3 — Assign host port to access VLAN

```
interface Ethernet3
   switchport access vlan 10   ! leaf1 and leaf3 (Tenant-A)
   ! OR
   switchport access vlan 20   ! leaf2 and leaf4 (Tenant-B)
```

### Task 4 — Configure the VXLAN interface

`Vxlan1` is the virtual VTEP interface. It maps VLANs to L2VNIs and VRFs to L3VNIs.

```
interface Vxlan1
   vxlan source-interface Loopback0
   vxlan udp-port 4789
   vxlan vlan 10 vni 10010
   vxlan vlan 20 vni 10020
   vxlan vrf TENANT-A vni 50001
   vxlan vrf TENANT-B vni 50002
```

### Task 5 — Configure SVIs (anycast IRB gateways)

`ip address virtual` creates an **anycast gateway** — the same IP and MAC on every leaf.
Hosts ARP for their gateway and get a consistent response regardless of which leaf
they're attached to.

```
interface Vlan10
   vrf TENANT-A
   ip address virtual 10.10.10.1/24
   no autostate

interface Vlan20
   vrf TENANT-B
   ip address virtual 10.20.20.1/24
   no autostate
```

### Task 6 — Configure BGP (underlay + EVPN overlay)

This is the heart of the lab. One `router bgp` process handles both:
- **IPv4 unicast** AF: eBGP underlay, advertises loopback for VTEP reachability
- **EVPN** AF: eBGP EVPN overlay, exchanges type-2/3/5 routes with spines

The spines use `next-hop-unchanged` so the VTEP loopback IP travels end-to-end
through the fabric unchanged — VXLAN tunnels form to the originating leaf's loopback,
not to the spine.

**Adjust these per leaf** (shown for leaf1):

```
router bgp 65001                           ! 65001/65002/65003/65004
   router-id 10.0.0.1                     ! 10.0.0.1/2/3/4
   maximum-paths 2 ecmp 2
   bgp bestpath as-path multipath-relax
   !
   neighbor 10.1.0.1 remote-as 65100      ! spine1 neighbor IP (see topology)
   neighbor 10.1.0.1 send-community extended  ! required: EOS eBGP strips ext-communities by default
   neighbor 10.2.0.1 remote-as 65200      ! spine2 neighbor IP (see topology)
   neighbor 10.2.0.1 send-community extended
   !
   address-family ipv4
      neighbor 10.1.0.1 activate
      neighbor 10.2.0.1 activate
      network 10.0.0.1/32                 ! advertise loopback (VTEP IP)
   !
   address-family evpn
      neighbor 10.1.0.1 activate
      neighbor 10.2.0.1 activate
   !
   ! L2VNI EVPN instances — same RT on all leaves (cross-leaf MAC/IP exchange)
   vlan 10
      rd auto
      route-target both 65000:10010
      redistribute learned
   !
   vlan 20
      rd auto
      route-target both 65000:10020
      redistribute learned
   !
   ! L3VPN EVPN instances — RD is per-leaf, RT is shared (cross-leaf routing)
   vrf TENANT-A
      rd 10.0.0.1:50001                   ! 10.0.0.X:50001 — use this leaf's loopback
      route-target import evpn 65000:50001
      route-target export evpn 65000:50001
      redistribute connected
   !
   vrf TENANT-B
      rd 10.0.0.1:50002                   ! 10.0.0.X:50002 — use this leaf's loopback
      route-target import evpn 65000:50002
      route-target export evpn 65000:50002
      redistribute connected
```

---

## Verification

Work through these steps after completing all tasks on all leaves.

### Step 1 — Underlay: BGP sessions and loopback reachability

```
! On any leaf:
show ip bgp summary
show ip route

! All four leaf loopbacks (10.0.0.1-4) and both spine loopbacks (10.0.0.101-102)
! should appear in the routing table.
! Verify ECMP — two paths via spine1 and spine2:
show ip route 10.0.0.2/32
```

### Step 2 — VXLAN: VTEP discovery and VNI status

```
! VTEPs learned via EVPN type-3 (IMET) routes — should show all remote leaf loopbacks
show vxlan vtep

! VNI table — each VNI shows remote VTEPs
show vxlan vni

! VXLAN interface detail
show interfaces Vxlan1
```

### Step 3 — BGP EVPN control plane

```
! Session summary — should show spine1 and spine2 Established
show bgp evpn summary

! All EVPN routes (type-2, type-3, type-5)
show bgp evpn

! Type-2 (MAC/IP) — populated after first ping from hosts
show bgp evpn route-type mac-ip

! Type-3 (IMET / flood list) — populated immediately on VNI creation
show bgp evpn route-type imet

! Type-5 (IP prefix) — connected subnets exported from each VRF
show bgp evpn route-type ip-prefix
```

### Step 4 — VRF routing tables

```
! Each leaf should see 10.10.10.0/24 as connected and from remote leaves via EVPN
show ip route vrf TENANT-A

! Tenant-B subnet — visible in TENANT-B VRF, NOT in TENANT-A VRF
show ip route vrf TENANT-B
```

### Step 5 — Trigger traffic and verify MAC learning

```
! Ping from host-a1 to host-a2 (cross-fabric, same tenant)
docker exec -it clab-vxlan-evpn-host-a1 Cli -c "ping 10.10.10.12 repeat 5"

! After ping — MAC address table should show remote MACs with VTEP next-hop
show mac address-table vlan 10

! ARP table in the VRF
show arp vrf TENANT-A

! VXLAN address table (MACs + their remote VTEP)
show vxlan address-table
```

### Step 6 — Segmentation validation (the key test)

```
! ✓ PASS — same tenant, cross-fabric
docker exec -it clab-vxlan-evpn-host-a1 Cli -c "ping 10.10.10.12 repeat 5"
docker exec -it clab-vxlan-evpn-host-b1 Cli -c "ping 10.20.20.12 repeat 5"

! ✗ FAIL — cross-tenant (must be blocked)
docker exec -it clab-vxlan-evpn-host-a1 Cli -c "ping 10.20.20.11 repeat 5"
docker exec -it clab-vxlan-evpn-host-b1 Cli -c "ping 10.10.10.11 repeat 5"

! Verify WHY it's blocked — Tenant-A has no route to Tenant-B subnet
show ip route vrf TENANT-A 10.20.20.0/24    ! should say "not found"
show ip route vrf TENANT-B 10.10.10.0/24    ! should say "not found"
```

### Step 7 — Observe VXLAN encapsulation

EOS has a built-in packet counter per VTEP tunnel. After pinging:

```
! Tx/Rx counters per remote VTEP
show vxlan data-plane detail

! Check tunnel encap — confirm VXLAN UDP/4789 is being used
show interfaces Vxlan1 counters
```

---

## How It Works

### Three-layer model

```
┌─────────────────────────────────────────────────────┐
│  Application layer: host-a1 ←→ host-a2             │
│  10.10.10.11                      10.10.10.12       │
├─────────────────────────────────────────────────────┤
│  Overlay (VXLAN): VNI 10010 tunnel                  │
│  leaf1 VTEP 10.0.0.1 ←→ leaf3 VTEP 10.0.0.3        │
│  BGP EVPN distributes MAC/IP and prefix routes      │
├─────────────────────────────────────────────────────┤
│  Underlay (eBGP): loopback reachability             │
│  leaf1 → spine1/spine2 → leaf3 (ECMP)              │
└─────────────────────────────────────────────────────┘
```

### EVPN route types in this lab

| Type | Name | What it carries | When generated |
|------|------|-----------------|----------------|
| 2 | MAC/IP | Host MAC + IP binding | After first packet from host |
| 3 | IMET | Flood list membership | When VNI is created |
| 5 | IP Prefix | Subnet route (10.10.10.0/24) | When VRF has connected route |

### Why `next-hop-unchanged` on the spines

When spine1 receives a type-2 route from leaf1 (VTEP IP 10.0.0.1), eBGP normally
replaces the next-hop with the spine's own IP before advertising to leaf3. That would
cause leaf3 to try to build a VXLAN tunnel to the spine — wrong.

`next-hop-unchanged` tells the spine to preserve the original next-hop (10.0.0.1),
so leaf3 builds its VXLAN tunnel directly to leaf1's loopback. This is the key
difference between using spines as EVPN route-reflectors in an eBGP fabric vs
a traditional iBGP route-reflector design.

### Anycast gateway

`ip address virtual 10.10.10.1/24` on every leaf's Vlan10 SVI creates an anycast
IRB gateway. Every leaf responds to ARP for 10.10.10.1 with the same virtual MAC
(`00:1c:73:aa:aa:aa`). This means:
- Hosts always use the local leaf as their L3 gateway (optimal routing)
- No GARP storms when a VM migrates — the MAC is the same everywhere
- Type-5 routes for 10.10.10.0/24 are advertised by every leaf (same prefix)

### Symmetric IRB and L3VNI

The L3VNI (50001/50002) enables **symmetric IRB** — L3 routing at both the ingress
and egress VTEP:

```
host-a1 → leaf1 (decap L2, route in TENANT-A VRF) → VXLAN L3VNI 50001 →
leaf3 (decap L3VNI, inject into VLAN 10) → host-a2
```

Without L3VNI, the ingress leaf would need to know the remote VLAN (asymmetric IRB) —
less scalable. With symmetric IRB, each leaf only needs its local VLANs; the L3VNI
carries the inter-VTEP routed traffic.

### Tenant segmentation

VRF TENANT-A and TENANT-B are completely separate routing domains. The EVPN
route-targets ensure:
- `65000:10010` routes (Tenant-A MACs) are only imported into Tenant-A VRFs
- `65000:10020` routes (Tenant-B MACs) are only imported into Tenant-B VRFs
- The VRFs have no routes to each other — there is no route leak configured

This is the EVPN equivalent of physical network segmentation, enforced in software.

---

## Challenge Exercises

1. **Add a fifth leaf** (`leaf5`, AS65005, loopback 10.0.0.5) with a new Tenant-A host
   (`host-a3`, 10.10.10.13). After configuring, verify host-a1 can ping host-a3 without
   any changes to the existing four leaves.

2. **Observe type-3 routes before any ping.** On leaf1: `show bgp evpn route-type imet`
   immediately after BGP comes up. What VTEP IPs do you see? Why do type-3 routes exist
   before any hosts have communicated?

3. **Watch a VXLAN packet.** SSH into the ContainerLab host and capture on the Linux
   bridge between leaf1 and spine1. You should see outer IP (leaf1→leaf3 loopback) with
   UDP/4789 carrying the inner Ethernet frame.

4. **Break and debug.** Change leaf3's EVPN route-target for vlan 10 to `65000:99999`.
   What happens to host-a1 ↔ host-a2 connectivity? What does `show bgp evpn route-type mac-ip`
   look like on leaf1? Restore it and confirm recovery.

5. **Verify ECMP in the underlay.** On leaf1: `show ip route 10.0.0.3/32`. You should
   see two equal-cost paths (via spine1 and spine2). Shut down `Ethernet1` on leaf1 and
   confirm connectivity still works through spine2 only.
