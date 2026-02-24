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
| r1:eth1 -- r2:eth1 | 10.1.12.0/30 | .1 | .2 | iBGP-LU (AS65001) |
| r2:eth2 -- r3:eth1 | 10.1.23.0/30 | .1 | .2 | eBGP-LU (inter-AS) |
| r3:eth2 -- r4:eth1 | 10.1.34.0/30 | .1 | .2 | iBGP-LU (AS65002) |

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
sudo containerlab deploy -t topology.yml
sudo containerlab destroy -t topology.yml
```

## What You Configure

The frr.conf files have IP addressing, OSPF, and MPLS interface configuration pre-done.
Your task is to configure BGP Labeled Unicast sessions on all four nodes.

### Step 1: Configure iBGP-LU within AS65001 (r1 and r2)

On **r1**:
```
vtysh
configure terminal

router bgp 65001
 no bgp ebgp-requires-policy
 bgp router-id 10.0.0.1
 neighbor 10.1.12.2 remote-as 65001
 !
 address-family ipv4 labeled-unicast
  neighbor 10.1.12.2 activate
  network 10.0.0.1/32

end
write memory
```

On **r2**:
```
router bgp 65001
 no bgp ebgp-requires-policy
 bgp router-id 10.0.0.2
 neighbor 10.1.12.1 remote-as 65001
 neighbor 10.1.23.2 remote-as 65002
 !
 address-family ipv4 labeled-unicast
  neighbor 10.1.12.1 activate
  neighbor 10.1.23.2 activate
  network 10.0.0.2/32
```

### Step 2: Configure eBGP-LU at the AS boundary (r2 and r3)

The eBGP-LU session between r2 (AS65001) and r3 (AS65002) is already partially configured above
on r2. On **r3**:

```
router bgp 65002
 no bgp ebgp-requires-policy
 bgp router-id 10.0.0.3
 neighbor 10.1.23.1 remote-as 65001
 neighbor 10.1.34.2 remote-as 65002
 !
 address-family ipv4 labeled-unicast
  neighbor 10.1.23.1 activate
  neighbor 10.1.34.2 activate
  network 10.0.0.3/32
```

### Step 3: Configure iBGP-LU within AS65002 (r3 and r4)

On **r4**:
```
router bgp 65002
 no bgp ebgp-requires-policy
 bgp router-id 10.0.0.4
 neighbor 10.1.34.1 remote-as 65002
 !
 address-family ipv4 labeled-unicast
  neighbor 10.1.34.1 activate
  network 10.0.0.4/32
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
show mpls table
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
show mpls table

# Full label details
show mpls table detail

# Interface MPLS status
show mpls interfaces

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

This is the FRR address family for BGP-LU. It is distinct from `address-family ipv4 unicast`.
You must explicitly activate neighbors in this AF:

```
address-family ipv4 labeled-unicast
 neighbor X.X.X.X activate
 network 10.0.0.1/32
```

### MPLS Interface Enablement

For labeled packets to be forwarded, each interface must have MPLS enabled:
```
interface eth1
 mpls enable
```
This is pre-configured in the frr.conf files. The exec also runs:
```
sysctl -w net.mpls.conf.eth1.input=1
```
to allow MPLS packet reception.

## Challenge Exercises

1. After configuring BGP-LU, run `traceroute 10.0.0.4 source 10.0.0.1` from r1.
   Do you see MPLS labels in the path? Why or why not?

2. Use `show bgp ipv4 labeled-unicast 10.0.0.1/32` on each router. Trace the label stack
   from r4's perspective back to r1 — what labels does each hop use?

3. Add a new loopback prefix (e.g., 192.168.99.1/32) on r1 and advertise it via BGP-LU.
   Verify it appears in r4's MPLS table with a proper label.

4. Compare `show mpls table` on r2 (transit ASBR) before and after configuring BGP-LU.
   What entries appear and how do they relate to the label bindings you see in BGP?

5. Try removing the `network 10.0.0.2/32` statement from r2's BGP-LU config.
   Does the end-to-end LSP break? What does this teach about label stitching at the ASBR?
