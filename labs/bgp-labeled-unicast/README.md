# Lab: bgp-labeled-unicast

## Purpose
Learn BGP Labeled Unicast (BGP-LU, RFC 3107) — the mechanism that signals MPLS labels via BGP
instead of LDP. Understand how inter-AS MPLS forwarding works (Option C style) where two ASes
exchange labeled prefixes at their border routers, enabling end-to-end MPLS label-switched paths.

## Topology

```
[r1]---10.1.12.0/30---[r2]---10.1.23.0/30---[r3]---10.1.34.0/30---[r4]
AS65001               AS65001|AS65002               AS65002
(iBGP-LU)           (ASBR)   (ASBR)               (iBGP-LU)
                      eBGP-LU border
```

| Link | Subnet | r-left | r-right | Session type |
|------|--------|--------|---------|--------------|
| r1:Ethernet1 -- r2:Ethernet1 | 10.1.12.0/30 | .1 | .2 | iBGP-LU (AS65001) |
| r2:Ethernet2 -- r3:Ethernet1 | 10.1.23.0/30 | .1 | .2 | eBGP-LU (inter-AS) |
| r3:Ethernet2 -- r4:Ethernet1 | 10.1.34.0/30 | .1 | .2 | iBGP-LU (AS65002) |

| Node | Loopback    | AS    | Role |
|------|-------------|-------|------|
| r1   | 10.0.0.1/32 | 65001 | Edge PE |
| r2   | 10.0.0.2/32 | 65001 | ASBR |
| r3   | 10.0.0.3/32 | 65002 | ASBR |
| r4   | 10.0.0.4/32 | 65002 | Edge PE |

OSPF runs within each AS (r1+r2 in AS65001, r3+r4 in AS65002) to provide loopback reachability.
MPLS is pre-enabled on all transit interfaces.

## Deploy / Destroy

```bash
sudo containerlab deploy -t topology.clab.yml
sudo containerlab destroy -t topology.clab.yml
```

Access a node:
```bash
docker exec -it clab-bgp-labeled-unicast-r1 Cli
```

## What You Configure

The startup-config files have IP addressing, OSPF, and `mpls ip` pre-configured on all interfaces.
Your task is to configure BGP Labeled Unicast sessions on all four nodes.

### Step 1: Configure iBGP-LU within AS65001 (r1 and r2)

For iBGP-LU in EOS, peers use loopback addresses (reachable via OSPF). The loopback-based iBGP
peer with `update-source Loopback0` is the correct approach.

On **r1**:
```
r1# configure
r1(config)# router bgp 65001
r1(config-router-bgp)# bgp router-id 10.0.0.1
r1(config-router-bgp)# neighbor 10.0.0.2 remote-as 65001
r1(config-router-bgp)# neighbor 10.0.0.2 update-source Loopback0
r1(config-router-bgp)# address-family ipv4 labeled-unicast
r1(config-router-bgp-af)# neighbor 10.0.0.2 activate
r1(config-router-bgp-af)# network 10.0.0.1/32
r1(config-router-bgp-af)# end
r1# write memory
```

On **r2**:
```
r2# configure
r2(config)# router bgp 65001
r2(config-router-bgp)# bgp router-id 10.0.0.2
r2(config-router-bgp)# neighbor 10.0.0.1 remote-as 65001
r2(config-router-bgp)# neighbor 10.0.0.1 update-source Loopback0
r2(config-router-bgp)# neighbor 10.1.23.2 remote-as 65002
r2(config-router-bgp)# address-family ipv4 labeled-unicast
r2(config-router-bgp-af)# neighbor 10.0.0.1 activate
r2(config-router-bgp-af)# neighbor 10.1.23.2 activate
r2(config-router-bgp-af)# network 10.0.0.2/32
r2(config-router-bgp-af)# end
r2# write memory
```

### Step 2: Configure eBGP-LU at the AS boundary (r2 and r3)

The eBGP-LU session between r2 (AS65001) and r3 (AS65002) is already partially configured above
on r2. On **r3**:

```
r3# configure
r3(config)# router bgp 65002
r3(config-router-bgp)# bgp router-id 10.0.0.3
r3(config-router-bgp)# neighbor 10.1.23.1 remote-as 65001
r3(config-router-bgp)# neighbor 10.0.0.4 remote-as 65002
r3(config-router-bgp)# neighbor 10.0.0.4 update-source Loopback0
r3(config-router-bgp)# address-family ipv4 labeled-unicast
r3(config-router-bgp-af)# neighbor 10.1.23.1 activate
r3(config-router-bgp-af)# neighbor 10.0.0.4 activate
r3(config-router-bgp-af)# network 10.0.0.3/32
r3(config-router-bgp-af)# end
r3# write memory
```

### Step 3: Configure iBGP-LU within AS65002 (r3 and r4)

On **r4**:
```
r4# configure
r4(config)# router bgp 65002
r4(config-router-bgp)# bgp router-id 10.0.0.4
r4(config-router-bgp)# neighbor 10.0.0.3 remote-as 65002
r4(config-router-bgp)# neighbor 10.0.0.3 update-source Loopback0
r4(config-router-bgp)# address-family ipv4 labeled-unicast
r4(config-router-bgp-af)# neighbor 10.0.0.3 activate
r4(config-router-bgp-af)# network 10.0.0.4/32
r4(config-router-bgp-af)# end
r4# write memory
```

### Step 4: Verify

Check BGP sessions are up:
```
show bgp ipv4 labeled-unicast summary
```

Check labeled routes are being exchanged:
```
show bgp ipv4 labeled-unicast
```

Check MPLS forwarding table:
```
show mpls lfib route
```

Test end-to-end connectivity:
```
ping 10.0.0.4 source 10.0.0.1
```

## Verification Commands

```
# BGP-LU session state
show bgp ipv4 labeled-unicast summary

# Full BGP-LU table (routes with assigned labels)
show bgp ipv4 labeled-unicast

# Specific prefix
show bgp ipv4 labeled-unicast 10.0.0.4/32

# MPLS forwarding entries (local label -> out-label, next-hop)
show mpls lfib route

# Full label details
show mpls lfib route detail

# Interface MPLS status
show mpls interface

# OSPF (underlay, within each AS)
show ip ospf neighbor
show ip route ospf
```

## Concepts

### What is BGP-LU?

BGP Labeled Unicast (RFC 3107) extends standard BGP to attach MPLS labels to advertised
prefixes. When a router sends a BGP-LU update, each prefix carries a label binding:
"to reach prefix X, use label Y."

This allows building MPLS label-switched paths (LSPs) using BGP as the signaling protocol,
without needing LDP or RSVP-TE.

### Why BGP-LU for Inter-AS MPLS?

In a single AS, LDP or SR-MPLS can distribute labels. But across AS boundaries, LDP is not
used. BGP-LU fills this gap:

```
AS65001                    AS65002
  r1 ---MPLS-LU--- r2 === r3 ---MPLS-LU--- r4
         iBGP-LU     eBGP-LU    iBGP-LU
```

Each ASBR (r2, r3) redistributes labeled routes between the two ASes, stitching together
the end-to-end LSP. This is called **Inter-AS Option C** (RFC 4364).

### Label Allocation

Each router independently allocates a label for each advertised prefix. When r4 advertises
its loopback 10.0.0.4/32 with label 17:
- r3 receives it with label 17 and assigns its own local label (e.g., 18)
- r3 advertises 10.0.0.4/32 with label 18 to r2
- r2 programs its MPLS table: incoming label 18 -> swap to 17 -> next-hop r3

### address-family ipv4 labeled-unicast

This is the EOS address family for BGP-LU. It is distinct from `address-family ipv4 unicast`.
You must explicitly activate neighbors in this AF:

```
address-family ipv4 labeled-unicast
 neighbor X.X.X.X activate
 network 10.0.0.1/32
```

### MPLS Interface Enablement

For labeled packets to be forwarded, each interface must have MPLS enabled:
```
interface Ethernet1
   mpls ip
```
This is pre-configured in the startup-config files.

## Challenge Exercises

1. After configuring BGP-LU, run `traceroute 10.0.0.4 source 10.0.0.1` from r1.
   Do you see MPLS labels in the path? Why or why not?

2. Use `show bgp ipv4 labeled-unicast 10.0.0.1/32` on each router. Trace the label stack
   from r4's perspective back to r1 — what labels does each hop use?

3. Add a new loopback prefix (e.g., 192.168.99.1/32) on r1 and advertise it via BGP-LU.
   Verify it appears in r4's MPLS table with a proper label.

4. Compare `show mpls lfib route` on r2 (transit ASBR) before and after configuring BGP-LU.
   What entries appear and how do they relate to the label bindings you see in BGP?

5. Try removing the `network 10.0.0.2/32` statement from r2's BGP-LU config.
   Does the end-to-end LSP break? What does this teach about label stitching at the ASBR?
