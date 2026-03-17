# Lab: OSPF Summarization (Inter-Area and External)

## Overview

This lab teaches two types of OSPF route summarization:

1. **Inter-area summarization** at an ABR — collapses multiple Type-3 Summary
   LSAs into one, reducing the size of the OSPF database in the backbone.
2. **External summarization** at an ASBR — collapses multiple Type-5 External
   LSAs from redistribution into one, preventing LSA flooding from a noisy
   external source (e.g., BGP table redistribution).

Summarization is a critical scaling tool. Without it, redistributing 500 BGP
prefixes into OSPF would flood 500 individual Type-5 LSAs to every router in
the domain. With `summary-address`, it becomes a single LSA.

## Topology

```mermaid
flowchart LR
    r1["r1\n10.1.1.1/32"]
    r2["r2 ABR\n10.0.0.2/32"]
    r3["r3 ABR+ASBR\n10.0.0.3/32"]
    r4["r4\n10.2.0.1/32"]
    ext(["ext\n192.168.100.2"])

    r1 -- "10.1.12.0/30\nArea 1" --- r2
    r2 -- "10.1.23.0/30\nArea 0" --- r3
    r3 -- "10.1.34.0/30\nArea 2" --- r4
    r3 -- "192.168.100.0/30\n(external)" --- ext

    classDef router fill:#1a1aff,color:#fff,stroke:#000
    classDef host   fill:#3d7a3d,color:#fff,stroke:#000
    class r1,r2,r3,r4 router
    class ext host
```

| Segment           | Subnet            | Addresses       | Area   |
|-------------------|-------------------|-----------------|--------|
| r1 -- r2          | 10.1.12.0/30      | r1=.1, r2=.2    | Area 1 |
| r2 -- r3          | 10.1.23.0/30      | r2=.1, r3=.2    | Area 0 |
| r3 -- r4          | 10.1.34.0/30      | r3=.1, r4=.2    | Area 2 |
| r3 -- ext         | 192.168.100.0/30  | r3=.1, ext=.2   | none   |
| r1 loopback (x3)  | 10.1.1.1, 10.1.2.1, 10.1.3.1 /32 | | Area 1 |
| r2 loopback       | 10.0.0.2/32       |                 | Area 0 |
| r3 loopback       | 10.0.0.3/32       |                 | Area 0 |
| r4 loopback       | 10.2.0.1/32       |                 | Area 2 |

**r2** is the ABR between Area 1 and Area 0.
**r3** is both the ABR between Area 0 and Area 2, and the ASBR for external routes.

## Lab Setup

```bash
sudo containerlab deploy -t topology.clab.yml
```

Connect to a router:
```bash
sudo docker exec -it clab-ospf-summarization-r4 Cli
```

## Step 1 — Add Extra Loopback Addresses on r1

<details>
<summary>Show configuration</summary>

To have multiple prefixes to summarize, add two more addresses to r1's loopback:

```
r1# configure terminal
r1(config)# interface Loopback0
r1(config-if)# ip address 10.1.2.1/32
r1(config-if)# ip address 10.1.3.1/32
```

These three prefixes (10.1.1.1/32, 10.1.2.1/32, 10.1.3.1/32) will all fall
within the summary range 10.1.0.0/22 used in Step 4.

</details>

## Step 2 — Configure Basic OSPF With Areas

<details>
<summary>Show configuration</summary>

Configure each router with OSPF, paying close attention to which interfaces
belong to which area. The area assignment is what makes r2 an ABR and r3 an ABR
for area 2.

On **r1** (all in area 1):
```
configure terminal
router ospf
 ospf router-id 10.1.1.1
 network 10.1.1.1/32 area 1
 network 10.1.2.1/32 area 1
 network 10.1.3.1/32 area 1
 network 10.1.12.0/30 area 1
 passive-interface Loopback0
```

On **r2** (Ethernet1 in area 1, loopback + Ethernet2 in area 0):
```
configure terminal
router ospf
 ospf router-id 10.0.0.2
 network 10.0.0.2/32 area 0
 network 10.1.12.0/30 area 1
 network 10.1.23.0/30 area 0
 passive-interface Loopback0
```

On **r3** (loopback + Ethernet1 in area 0, Ethernet2 in area 2, Ethernet3 is external):
```
configure terminal
router ospf
 ospf router-id 10.0.0.3
 network 10.0.0.3/32 area 0
 network 10.1.23.0/30 area 0
 network 10.1.34.0/30 area 2
 passive-interface Loopback0
```

On **r4** (all in area 2):
```
configure terminal
router ospf
 ospf router-id 10.2.0.1
 network 10.2.0.1/32 area 2
 network 10.1.34.0/30 area 2
 passive-interface Loopback0
```

Verify all adjacencies are `Full`:
```
r3# show ip ospf neighbor
```

</details>

### Examine the OSPF Database — Before Summarization

From r4 (furthest from area 1), look at the database:
```
r4# show ip ospf database
```

You should see three separate Type-3 Summary LSAs, one for each /32 from r1
(10.1.1.1, 10.1.2.1, 10.1.3.1). This is the problem summarization solves.

```
r4# show ip ospf database summary
```

Note the LSA count. You will compare this after enabling summarization.

## Step 3 — Redistribute External Routes on r3 (ASBR)

<details>
<summary>Show configuration</summary>

First, add a static route on r3 for the external network:
```
r3# configure terminal
r3(config)# ip route 192.168.100.0/24 192.168.100.2
```

Then redistribute it into OSPF:
```
r3(config)# router ospf
r3(config-router)# redistribute static
```

Check from r4:
```
r4# show ip ospf database external
r4# show ip route ospf
```

You should see `O E2 192.168.100.0/24` in r4's routing table. The `E2` means
the metric is fixed (does not accumulate intra-domain cost) — explained below.

</details>

## Step 4 — Inter-Area Summarization at r2 (ABR)

<details>
<summary>Show configuration</summary>

Now configure r2 to summarize all area 1 routes in the 10.1.0.0/22 range into
a single Type-3 LSA:

```
r2# configure terminal
r2(config)# router ospf
r2(config-router)# area 1 range 10.1.0.0/22
```

Immediately verify the change from r4:
```
r4# show ip ospf database summary
```

Before: three separate /32 entries for 10.1.1.1, 10.1.2.1, 10.1.3.1.
After: a single entry for 10.1.0.0/22.

```
r4# show ip route ospf
```

Before: `O IA 10.1.1.1/32`, `O IA 10.1.2.1/32`, `O IA 10.1.3.1/32`
After: `O IA 10.1.0.0/22`

The summary prefix metric is the **maximum** cost among all contributing
specific routes.

</details>

### Suppressing a Range With not-advertise

You can completely hide a range from other areas:
```
r2(config-router)# area 1 range 10.1.0.0/22 not-advertise
```

After this, r4 has **no route** to any 10.1.x.x prefix — the range is suppressed
entirely. This is useful for hiding internal prefixes or for traffic engineering.

To restore normal summarization:
```
r2(config-router)# area 1 range 10.1.0.0/22
```
(Remove `not-advertise` by reissuing the command without it.)

## Step 5 — External Summarization at r3 (ASBR)

<details>
<summary>Show configuration</summary>

If r3 were redistributing many external prefixes (simulating BGP), you would
want to summarize them. Configure the summary on r3:

```
r3# configure terminal
r3(config)# router ospf
r3(config-router)# summary-address 192.168.100.0/24
```

Check from r4:
```
r4# show ip ospf database external
```

Any redistributed routes within 192.168.100.0/24 are now represented by a
single Type-5 LSA. Without this, each individual prefix would generate its own
Type-5 LSA flooded to every router in the entire OSPF domain.

</details>

## LSA Type Reference

| LSA Type | Name           | Generated by | Scope              | Purpose                        |
|----------|----------------|--------------|--------------------|--------------------------------|
| Type-1   | Router LSA     | Every router | Within area        | Links and costs within an area |
| Type-2   | Network LSA    | DR           | Within area        | Multi-access segment info      |
| Type-3   | Summary LSA    | ABR          | Other areas        | Inter-area prefix reachability |
| Type-4   | ASBR Summary   | ABR          | Other areas        | Location of ASBR               |
| Type-5   | External LSA   | ASBR         | Entire OSPF domain | Redistributed external routes  |

Key insight: Type-5 LSAs are flooded to the **entire domain** (except stub
areas). This is why external summarization at ASBRs is so important — a
single noisy redistribution source (e.g., partial BGP table) can flood
thousands of Type-5 LSAs to every router.

## E1 vs E2 External Metrics

When redistributing routes, OSPF supports two external metric types:

**E2 (default):** The cost assigned at the ASBR is the only cost. It does NOT
increase as the route traverses OSPF routers. All routers see the same E2 cost.
Use E2 when the external path cost dominates and intra-domain cost is irrelevant.

**E1:** The external cost PLUS intra-domain (OSPF) cost to reach the ASBR.
Use E1 when you have multiple ASBRs redistributing the same external prefix and
you want routers to prefer the topologically closer ASBR.

Change the metric type using a route-map (EOS does not support inline `metric-type` on the `redistribute` command):

<details>
<summary>Show configuration</summary>

```
r3(config)# route-map OSPF-E1 permit 10
r3(config-route-map)# set metric-type type-1
r3(config-route-map)# exit
r3(config)# router ospf 1
r3(config-router)# redistribute static route-map OSPF-E1
```
</details>

Observe the change in `show ip route ospf` on r4:
- E2 shows `O E2` with a fixed metric
- E1 shows `O E1` with a metric that changes depending on distance to r3

## Troubleshooting Reference

| Command | What to look for |
|---------|-----------------|
| `show ip ospf neighbor` | All neighbors in `Full` state |
| `show ip ospf database` | Total LSA count — compare before/after summarization |
| `show ip ospf database summary` | Type-3 LSAs — should collapse after ABR summarization |
| `show ip ospf database external` | Type-5 LSAs — should collapse after ASBR summarization |
| `show ip route ospf` | `O IA` = inter-area, `O E2` = external type 2 |
| `show ip ospf border-routers` | Lists known ABRs and ASBRs |

## Cleanup

```bash
sudo containerlab destroy -t topology.clab.yml
```

## Extensions

These are optional follow-on ideas to deepen the lab. They are not part of the validated base workflow.

- Deliberately summarize too broadly and observe the black-hole risk when a component subnet disappears behind the summary.
- Compare inter-area summarization on the ABR to external summarization on the ASBR and document which LSAs each affects.
- Redistribute the same routes as E1 and E2 at different times and compare how path cost changes downstream.
- Capture OSPF updates during summarization changes and correlate them with the shrinking or growing LSDB.
