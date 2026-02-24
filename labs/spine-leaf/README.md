# Lab: spine-leaf

## Purpose
Learn BGP-based spine-leaf (CLOS) fabric underlay — the foundation of modern data center
networking. Understand why eBGP replaces traditional IGPs in DC environments, how ECMP
provides equal-cost multipath across redundant uplinks, and why each device gets its own
unique AS number in this design.

## Topology

```
        [spine1]             [spine2]
        AS65100               AS65200
   .1  .3  .5  .7        .1  .3  .5  .7
    |   |   |   |          |   |   |   |
   .0  .2  .4  .6        .0  .2  .4  .6
  eth1 eth1 eth1 eth1   eth2 eth2 eth2 eth2
[leaf1][leaf2][leaf3][leaf4]
AS65001 AS65002 AS65003 AS65004
```

### Links (/31 subnets)

| Link | Subnet | Leaf IP | Spine IP |
|------|--------|---------|----------|
| leaf1:eth1 -- spine1:eth1 | 10.1.0.0/31 | .0 | .1 |
| leaf2:eth1 -- spine1:eth2 | 10.1.0.2/31 | .2 | .3 |
| leaf3:eth1 -- spine1:eth3 | 10.1.0.4/31 | .4 | .5 |
| leaf4:eth1 -- spine1:eth4 | 10.1.0.6/31 | .6 | .7 |
| leaf1:eth2 -- spine2:eth1 | 10.2.0.0/31 | .0 | .1 |
| leaf2:eth2 -- spine2:eth2 | 10.2.0.2/31 | .2 | .3 |
| leaf3:eth2 -- spine2:eth3 | 10.2.0.4/31 | .4 | .5 |
| leaf4:eth2 -- spine2:eth4 | 10.2.0.6/31 | .6 | .7 |

### Node Summary

| Node | Loopback | AS |
|------|----------|----|
| spine1 | 10.0.0.101/32 | 65100 |
| spine2 | 10.0.0.102/32 | 65200 |
| leaf1 | 10.0.0.1/32 | 65001 |
| leaf2 | 10.0.0.2/32 | 65002 |
| leaf3 | 10.0.0.3/32 | 65003 |
| leaf4 | 10.0.0.4/32 | 65004 |

## Deploy / Destroy

```bash
sudo containerlab deploy -t topology.yml
sudo containerlab destroy -t topology.yml
```

## What You Configure

Interface IPs and loopbacks are pre-configured. Your task is to configure BGP on all 6 nodes.

### Step 1: Configure spine1 (AS65100)

```bash
docker exec -it clab-spine-leaf-spine1 vtysh
configure terminal

router bgp 65100
 no bgp ebgp-requires-policy
 bgp router-id 10.0.0.101
 bgp bestpath as-path multipath-relax
 maximum-paths 4
 neighbor 10.1.0.0 remote-as 65001
 neighbor 10.1.0.2 remote-as 65002
 neighbor 10.1.0.4 remote-as 65003
 neighbor 10.1.0.6 remote-as 65004
 !
 address-family ipv4 unicast
  network 10.0.0.101/32
  neighbor 10.1.0.0 activate
  neighbor 10.1.0.2 activate
  neighbor 10.1.0.4 activate
  neighbor 10.1.0.6 activate

end
write memory
```

### Step 2: Configure spine2 (AS65200)

```bash
docker exec -it clab-spine-leaf-spine2 vtysh
configure terminal

router bgp 65200
 no bgp ebgp-requires-policy
 bgp router-id 10.0.0.102
 bgp bestpath as-path multipath-relax
 maximum-paths 4
 neighbor 10.2.0.0 remote-as 65001
 neighbor 10.2.0.2 remote-as 65002
 neighbor 10.2.0.4 remote-as 65003
 neighbor 10.2.0.6 remote-as 65004
 !
 address-family ipv4 unicast
  network 10.0.0.102/32
  neighbor 10.2.0.0 activate
  neighbor 10.2.0.2 activate
  neighbor 10.2.0.4 activate
  neighbor 10.2.0.6 activate

end
write memory
```

### Step 3: Configure leaf1 (AS65001)

```bash
docker exec -it clab-spine-leaf-leaf1 vtysh
configure terminal

router bgp 65001
 no bgp ebgp-requires-policy
 bgp router-id 10.0.0.1
 bgp bestpath as-path multipath-relax
 maximum-paths 2
 neighbor 10.1.0.1 remote-as 65100
 neighbor 10.2.0.1 remote-as 65200
 !
 address-family ipv4 unicast
  network 10.0.0.1/32
  neighbor 10.1.0.1 activate
  neighbor 10.2.0.1 activate

end
write memory
```

### Step 4: Configure leaf2, leaf3, leaf4

Same pattern — adjust router-id, network, and neighbor IPs per the link table above:

| Node | router-id | network | spine1 neighbor | spine2 neighbor |
|------|-----------|---------|-----------------|-----------------|
| leaf2 | 10.0.0.2 | 10.0.0.2/32 | 10.1.0.3 (AS65100) | 10.2.0.3 (AS65200) |
| leaf3 | 10.0.0.3 | 10.0.0.3/32 | 10.1.0.5 (AS65100) | 10.2.0.5 (AS65200) |
| leaf4 | 10.0.0.4 | 10.0.0.4/32 | 10.1.0.7 (AS65100) | 10.2.0.7 (AS65200) |

### Step 5: Verify

```bash
# Check BGP sessions on spine1 (should show 4 neighbors Established)
docker exec clab-spine-leaf-spine1 vtysh -c "show bgp ipv4 unicast summary"

# Check ECMP routes on leaf1 (should see leaf2/3/4 loopbacks via both spines)
docker exec clab-spine-leaf-leaf1 vtysh -c "show ip route bgp"

# Ping leaf2 loopback from leaf1 (ECMP across both spines)
docker exec clab-spine-leaf-leaf1 ping -c3 10.0.0.2
```

## Verification Commands

```
# BGP session summary (Established state, prefix counts)
show bgp ipv4 unicast summary

# Full BGP table (all learned routes)
show bgp ipv4 unicast

# Routing table with ECMP (look for lines with [2] or multiple nexthops)
show ip route bgp

# ECMP detail for a specific prefix
show ip route 10.0.0.2/32

# BGP neighbor detail (AS number, session stats)
show bgp neighbors 10.1.0.0

# Check BFD sessions (after enabling BFD on neighbors)
show bfd peers
```

## Concepts

### Why eBGP in the Data Center?

Traditional DC networks used STP for L2 or OSPF/EIGRP for L3. Modern DC networks use
eBGP because:
- **Scalability**: BGP handles internet-scale routing; easily extends to thousands of nodes
- **Simplicity**: no protocol-specific tuning (DR/BDR, area design, redistribution)
- **ECMP**: BGP multipath naturally load-balances across equal-cost paths
- **Vendor-neutral**: standard protocol supported by all vendors and OSS (FRR, BIRD)

### Unique AS Per Device

Each device gets its own AS number (BGP Autonomous System). This is the standard RFC 7938
design for DC BGP:

- Leaves: each in its own AS (65001–65004)
- Spines: each in its own AS (65100, 65200)

Without unique ASes, BGP would refuse to accept a route that already contains its own AS
in the path (loop prevention). Unique ASes eliminate this problem.

### bgp bestpath as-path multipath-relax

When spine1 learns 10.0.0.1/32 from leaf1 (path: 65001) and 10.0.0.2/32 from leaf2
(path: 65002), these routes have different AS paths. Normally BGP would not consider them
equal-cost. `as-path multipath-relax` allows routes with different AS paths to qualify
for ECMP as long as all other attributes are equal.

### /31 Subnets

RFC 3021 allows /31 subnets on point-to-point links, saving IPv4 address space. A /31
has 2 addresses: .0 (typically leaf) and .1 (typically spine). No broadcast address is
needed on a point-to-point link.

### ECMP in Action

After full configuration, each leaf will see routes to every other leaf's loopback with
**two equal-cost paths** (via spine1 and spine2). Traffic is hashed per-flow across both
uplinks, giving full bandwidth utilization of both spine connections.

## Challenge Exercises

1. Bring down spine1 (`docker exec clab-spine-leaf-spine1 ip link set eth1 down`).
   Watch `show ip route bgp` on leaf1 — how quickly does the route shift to only spine2?

2. Add simulated server prefixes: on leaf1, add `network 172.16.1.0/24` to the BGP config
   and verify leaf2/3/4 can ping 172.16.1.1 (after adding the IP to leaf1's loopback).

3. Enable BFD on all BGP sessions for sub-second failure detection:
   ```
   router bgp 65001
    neighbor 10.1.0.1 bfd
    neighbor 10.2.0.1 bfd
   ```
   Repeat on all nodes. Compare convergence time with and without BFD.

4. Add a route-map on leaf1 to prefer spine1 over spine2 using LOCAL_PREF:
   set local-preference 200 for routes from spine1, 100 from spine2.
   Verify `show bgp ipv4 unicast` shows spine1 routes as preferred.

5. Replace per-neighbor config on spine1 with peer-groups to reduce config verbosity:
   ```
   neighbor LEAVES peer-group
   neighbor LEAVES remote-as external
   bgp listen range 10.1.0.0/24 peer-group LEAVES
   ```
   Does this simplify the config? What are the trade-offs?
