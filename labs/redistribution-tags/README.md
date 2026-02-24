# Lab: Redistribution Tags — Loop Prevention

## Overview

This lab teaches how route tags prevent routing loops when two ASBRs perform
mutual redistribution between OSPF and EIGRP. This is a classic problem in
networks with dual redistribution points.

## Topology

```
[r1]--OSPF--[asbr1]--EIGRP--[r2]--EIGRP--[asbr2]--OSPF--[r3]
              ^                              ^
         redistributes                 redistributes
         EIGRP->OSPF                   OSPF->EIGRP
         OSPF->EIGRP                   EIGRP->OSPF
```

Two separate OSPF area 0 domains, one EIGRP AS 100 domain in the middle.

## IP Addressing

| Node  | Interface | Address         | Protocol    |
|-------|-----------|-----------------|-------------|
| r1    | lo        | 10.0.0.1/32     | OSPF area 0 |
| r1    | eth1      | 10.1.10.1/30    | OSPF area 0 |
| asbr1 | lo        | 10.0.0.2/32     | both        |
| asbr1 | eth1      | 10.1.10.2/30    | OSPF area 0 |
| asbr1 | eth2      | 10.2.10.1/30    | EIGRP 100   |
| r2    | lo        | 10.0.0.3/32     | EIGRP 100   |
| r2    | eth1      | 10.2.10.2/30    | EIGRP 100   |
| r2    | eth2      | 10.2.20.1/30    | EIGRP 100   |
| asbr2 | lo        | 10.0.0.4/32     | both        |
| asbr2 | eth1      | 10.2.20.2/30    | EIGRP 100   |
| asbr2 | eth2      | 10.1.30.1/30    | OSPF area 0 |
| r3    | lo        | 10.0.0.5/32     | OSPF area 0 |
| r3    | eth1      | 10.1.30.2/30    | OSPF area 0 |

## Lab Steps

### Step 1: Start the lab

```bash
sudo containerlab deploy -t topology.yml
```

### Step 2: Configure OSPF (left domain — r1 and asbr1)

On **r1**:
```
vtysh
conf t
router ospf
 router-id 10.0.0.1
 network 10.0.0.1/32 area 0
 network 10.1.10.0/30 area 0
```

On **asbr1**:
```
vtysh
conf t
router ospf
 router-id 10.0.0.2
 network 10.0.0.2/32 area 0
 network 10.1.10.0/30 area 0
```

### Step 3: Configure OSPF (right domain — asbr2 and r3)

On **asbr2**:
```
vtysh
conf t
router ospf
 router-id 10.0.0.4
 network 10.0.0.4/32 area 0
 network 10.1.30.0/30 area 0
```

On **r3**:
```
vtysh
conf t
router ospf
 router-id 10.0.0.5
 network 10.0.0.5/32 area 0
 network 10.1.30.0/30 area 0
```

### Step 4: Configure EIGRP AS 100

On **asbr1**, **r2**, and **asbr2**:
```
vtysh
conf t
router eigrp 100
 network 10.0.0.X/32        ! (use node's loopback)
 network 10.2.XX.0/30       ! (use node's EIGRP links)
```

Verify: `show ip eigrp neighbors` should show adjacencies on all EIGRP nodes.

### Step 5: Mutual redistribution WITHOUT tags (observe the problem)

On **asbr1**:
```
vtysh
conf t
route-map EIGRP-TO-OSPF permit 10
route-map OSPF-TO-EIGRP permit 10
router ospf
 redistribute eigrp route-map EIGRP-TO-OSPF
router eigrp 100
 redistribute ospf route-map OSPF-TO-EIGRP
```

On **asbr2** (mirror):
```
vtysh
conf t
route-map EIGRP-TO-OSPF permit 10
route-map OSPF-TO-EIGRP permit 10
router ospf
 redistribute eigrp route-map EIGRP-TO-OSPF
router eigrp 100
 redistribute ospf route-map OSPF-TO-EIGRP
```

#### Observe the loop problem

On **r1**:
```
show ip route
```

You will see routes from r3's OSPF domain (10.0.0.5, 10.1.30.0/30) appearing as
OSPF external routes. These came from: r3 -> asbr2 (OSPF) -> EIGRP -> asbr1 -> OSPF.

Now look on **r3**:
```
show ip route
```

Routes from r1's domain appear as OSPF external routes too. So far so good —
that is the desired reachability.

**The problem**: On **asbr1**, run:
```
show ip eigrp topology
```

You may see routes that originated in OSPF (e.g. r1's loopback 10.0.0.1) being
redistributed back into EIGRP by asbr2, then coming back to asbr1, creating a
potential loop. With two ASBRs, a route can bounce: OSPF-left -> EIGRP -> OSPF-right
-> EIGRP -> OSPF-left (loop).

### Step 6: Fix with route tags

The solution: each ASBR stamps routes with a tag when redistributing, and denies
routes with the other direction's tag on the way back.

**Tag convention for this lab:**
- Tag 100: routes redistributed from OSPF into EIGRP
- Tag 200: routes redistributed from EIGRP into OSPF

On **asbr1** — replace the permit-only maps:
```
vtysh
conf t
no route-map EIGRP-TO-OSPF permit 10
no route-map OSPF-TO-EIGRP permit 10

! Block routes that were originally OSPF (tag 100) from going back into OSPF
route-map EIGRP-TO-OSPF deny 10
 match tag 100
route-map EIGRP-TO-OSPF permit 20
 set tag 200

! Block routes that were originally EIGRP (tag 200) from going back into EIGRP
route-map OSPF-TO-EIGRP deny 10
 match tag 200
route-map OSPF-TO-EIGRP permit 20
 set tag 100
```

On **asbr2** — identical configuration:
```
vtysh
conf t
no route-map EIGRP-TO-OSPF permit 10
no route-map OSPF-TO-EIGRP permit 10

route-map EIGRP-TO-OSPF deny 10
 match tag 100
route-map EIGRP-TO-OSPF permit 20
 set tag 200
route-map OSPF-TO-EIGRP deny 10
 match tag 200
route-map OSPF-TO-EIGRP permit 20
 set tag 100
```

### Step 7: Verify loop-free operation

On **r1**:
```
show ip route
```
Expect: r3's loopback 10.0.0.5 and prefix 10.1.30.0/30 as O E2 routes.
Should NOT see routes looping back (e.g. 10.0.0.1 should not appear as external).

On **r3**:
```
show ip route
```
Expect: r1's loopback 10.0.0.1 and prefix 10.1.10.0/30 as O E2 routes.

On **r1**, ping r3's loopback:
```
ping 10.0.0.5 source 10.0.0.1
```

Check OSPF database for tag presence:
```
show ip ospf database external
```
External LSAs should show tag 200 (redistributed from EIGRP into OSPF).

## Key Concepts

### Why loops happen

When two ASBRs both redistribute between the same two protocols:

1. Route X originates in OSPF (left)
2. asbr1 redistributes X into EIGRP
3. asbr2 sees X in EIGRP, redistributes it back into OSPF (right)
4. asbr1 sees X coming back in OSPF (right), redistributes it back into EIGRP
5. Loop: X bounces forever with increasing metrics

### How tags prevent loops

Tags are integers attached to redistributed routes. The rule is simple:
- When a route enters a protocol, tag it to show where it came from
- When redistributing back to the source protocol, deny routes with that tag

This ensures a route redistributed OSPF->EIGRP is never redistributed back
EIGRP->OSPF by the other ASBR.

### Tag matching in FRR

```
route-map NAME deny 10
 match tag 100        ! Drop routes with tag 100

route-map NAME permit 20
 set tag 200          ! Apply tag 200 to accepted routes
```

Tags propagate with the route through the protocol. OSPF carries tags in
external LSAs. EIGRP carries tags in the topology table.

### Verification commands

```
show ip route                          ! Check routing table
show ip ospf database external         ! OSPF external LSAs with tags
show ip eigrp topology                 ! EIGRP topology table with tags
show route-map                         ! Route-map hit counters
```

## Teardown

```bash
sudo containerlab destroy -t topology.yml
```
