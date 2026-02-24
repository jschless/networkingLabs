# Lab: BGP Communities

## Overview

BGP communities are optional transitive attributes — small numeric tags attached to
route announcements. They let routers signal intent to their peers: "treat this route
specially", "don't export this", "give this higher preference". Communities travel with
the prefix across AS boundaries (unless stripped).

This lab uses a four-node linear topology across four autonomous systems. You will
configure base BGP, then progressively add community tagging and matching policy.

## Topology

```
[r1]---eth1---eth1---[r2]---eth2---eth1---[r3]---eth2---eth1---[r4]
AS65001               AS65002               AS65003               AS65004
10.0.0.1/32           10.0.0.2/32           10.0.0.3/32           10.0.0.4/32
```

### Link Addresses

| Link           | r1 side        | r2 side        |
|----------------|----------------|----------------|
| r1:eth1-r2:eth1 | 10.1.12.1/30  | 10.1.12.2/30   |
| r2:eth2-r3:eth1 | 10.1.23.1/30  | 10.1.23.2/30   |
| r3:eth2-r4:eth1 | 10.1.34.1/30  | 10.1.34.2/30   |

## Deploy and Destroy

```bash
sudo containerlab deploy -t topology.yml
sudo containerlab destroy -t topology.yml
```

## Access Nodes

```bash
sudo docker exec -it clab-bgp-communities-r1 vtysh
sudo docker exec -it clab-bgp-communities-r2 vtysh
sudo docker exec -it clab-bgp-communities-r3 vtysh
sudo docker exec -it clab-bgp-communities-r4 vtysh
```

---

## Background: BGP Communities

### What is a community?

A community is a 32-bit value attached to a BGP prefix, written in `AA:NN` format
(each part 0–65535). Multiple communities can be attached to the same prefix.

Communities are:
- **Optional transitive**: they propagate to eBGP peers by default
- **Human-defined**: their meaning is local agreement between operators
- **Actionable**: routers match on them and apply policy (prefer, drop, tag)

### Standard vs Extended vs Large Communities

| Type      | Format         | Size    | Use case                              |
|-----------|---------------|---------|---------------------------------------|
| Standard  | `AA:NN`       | 32-bit  | General tagging, most common          |
| Extended  | `type:AA:NN`  | 64-bit  | MPLS VPN route targets, traffic eng   |
| Large     | `AA:NN1:NN2`  | 96-bit  | Large ASNs, more granular values      |

This lab focuses on standard communities.

### Well-Known Communities (RFC 1997)

These have globally defined meanings, no AA:NN negotiation needed:

| Community      | Meaning                                                             |
|----------------|---------------------------------------------------------------------|
| `no-export`    | Do not advertise beyond the local AS (or confederation)             |
| `no-advertise` | Do not advertise to any BGP peer at all                             |
| `local-AS`     | Do not send outside the local confederation sub-AS                  |
| `internet`     | Advertise to all (default, rarely set explicitly)                   |

---

## FRR Configuration Reference

### Setting a community on outbound routes

```
! Define the route-map
route-map SET-COMM permit 10
 set community 65001:100

! Apply to a neighbor (outbound)
router bgp 65001
 address-family ipv4 unicast
  neighbor 10.1.12.2 route-map SET-COMM out
```

### Setting a well-known community

```
route-map SET-NOEXPORT permit 10
 set community no-export

! Or combine: set community 65001:100 no-export additive
! "additive" appends to existing communities rather than replacing them
```

### Matching a community inbound

```
! Step 1: define a community-list
bgp community-list standard MY-COMM permit 65001:100

! Step 2: create route-map that matches it
route-map MATCH-COMM permit 10
 match community MY-COMM
 set local-preference 200
route-map MATCH-COMM permit 20
 ! permit everything else (no match = default action of permit)

! Step 3: apply to neighbor
router bgp 65002
 address-family ipv4 unicast
  neighbor 10.1.12.1 route-map MATCH-COMM in
```

### Stripping communities

```
route-map STRIP-COMM permit 10
 set community none
```

### Applying changes without dropping sessions

```
clear ip bgp * soft in    ! Re-evaluate inbound policy
clear ip bgp * soft out   ! Re-advertise with updated outbound policy
```

---

## Tasks

### Task 1 — Base BGP (all four routers)

Configure BGP on all four nodes. Each node peers with its neighbor(s).
Advertise the loopback (/32) from each node.

Always include `no bgp ebgp-requires-policy` to disable FRR's default
policy requirement for eBGP peers.

Expected result:
```
r4# show bgp ipv4 unicast
   Network          Next Hop        Metric LocPrf Weight Path
*> 10.0.0.1/32      10.1.34.1                          0 65003 65002 65001 i
*> 10.0.0.2/32      10.1.34.1                          0 65003 65002 i
*> 10.0.0.3/32      10.1.34.1                          0 65003 i
*> 10.0.0.4/32      0.0.0.0                            0 32768 i
```

### Task 2 — Tag a route with a standard community

On r1, create a route-map that sets community `65001:100` on the loopback prefix
and apply it outbound to r2.

Verify on r2:
```
r2# show bgp ipv4 unicast 10.0.0.1/32
  Community: 65001:100
```

On r3 and r4, the community should still be visible (communities propagate by default).

### Task 3 — Match community and set local-preference on r2

On r2, match inbound routes tagged with `65001:100` and set local-preference 200.

```
bgp community-list standard PREF-TAG permit 65001:100

route-map HONOR-TAG permit 10
 match community PREF-TAG
 set local-preference 200
route-map HONOR-TAG permit 20

router bgp 65002
 address-family ipv4 unicast
  neighbor 10.1.12.1 route-map HONOR-TAG in
```

Verify:
```
r2# show bgp ipv4 unicast 10.0.0.1/32
  Local preference: 200
```

### Task 4 — Apply no-export from r1

Change r1's outbound route-map to set community `no-export`:

```
route-map SET-COMM permit 10
 set community no-export
```

Apply: `clear ip bgp * soft out` on r1.

Expected: r2 accepts the route but does NOT advertise to r3.
- r2: `show bgp ipv4 unicast` → 10.0.0.1/32 is present
- r3: `show bgp ipv4 unicast` → 10.0.0.1/32 is ABSENT
- r4: `show bgp ipv4 unicast` → 10.0.0.1/32 is ABSENT

### Task 5 — Apply no-advertise from r1

Change to `no-advertise`:

```
route-map SET-COMM permit 10
 set community no-advertise
```

Expected: r2 keeps the route in its local RIB but does not advertise it to
ANY neighbor — not even r3.
- r2: route is present, marked with community no-advertise
- r3: route is absent
- r4: route is absent

### Task 6 — Strip communities before forwarding

On r2, strip the community from r1's prefix before forwarding to r3:

```
route-map STRIP-COMM permit 10
 set community none

router bgp 65002
 address-family ipv4 unicast
  neighbor 10.1.23.2 route-map STRIP-COMM out
```

Verify: r3 receives 10.0.0.1/32 but with no community attached.
```
r3# show bgp ipv4 unicast 10.0.0.1/32
  (no Community line in output)
```

### Task 7 — Combine communities

On r1, set multiple communities at once using `additive`:

```
route-map SET-COMM permit 10
 set community 65001:100 65001:200 additive
```

The `additive` keyword is important: without it, `set community` replaces
all existing communities. With `additive`, it appends to whatever is already set.

---

## Useful Show Commands

```
show bgp ipv4 unicast                        # BGP table
show bgp ipv4 unicast 10.0.0.1/32           # Detail for a specific prefix
show bgp community 65001:100                 # All prefixes with this community
show bgp community no-export                 # All prefixes with no-export
show route-map                               # All configured route-maps
show bgp community-list                      # All community-lists
show ip bgp summary                          # Neighbor session status
```

## Troubleshooting

**Community not appearing on neighbor**
- Did you apply `send-community` to the neighbor?
  FRR sends standard communities by default for eBGP, but double-check:
  `neighbor X.X.X.X send-community`
- Did you `clear ip bgp * soft out` after changing the route-map?

**Route not being suppressed by no-export**
- Check the community is actually set: `show bgp ipv4 unicast <prefix>` on the sending router
- Make sure the route-map is applied outbound: `show bgp neighbors X.X.X.X | include route-map`

**Route-map not matching**
- Community-list name must match exactly between `bgp community-list` and `match community`
- Check: `show bgp community-list`
- Verify with: `show route-map MATCH-COMM`
