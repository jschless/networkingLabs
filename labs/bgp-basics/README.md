# BGP Basics — Practice Lab

Build a four-router BGP network spanning three autonomous systems. IP addressing is pre-configured. You implement all BGP sessions, advertise prefixes, and work through the classic iBGP next-hop problem.

---

## Topology

```
[r1] --eBGP-- [r2] --iBGP-- [r3] --eBGP-- [r4]
AS65001       AS65002        AS65002        AS65003
```

### Link addressing

| Link    | Subnet       | Left       | Right      | Type |
|---------|--------------|------------|------------|------|
| r1 — r2 | 10.1.12.0/30 | 10.1.12.1  | 10.1.12.2  | eBGP |
| r2 — r3 | 10.1.23.0/30 | 10.1.23.1  | 10.1.23.2  | iBGP |
| r3 — r4 | 10.1.34.0/30 | 10.1.34.1  | 10.1.34.2  | eBGP |

### Node reference

| Node | Loopback    | ASN   | Role                     |
|------|-------------|-------|--------------------------|
| r1   | 10.0.0.1/32 | 65001 | eBGP speaker             |
| r2   | 10.0.0.2/32 | 65002 | eBGP to r1, iBGP to r3   |
| r3   | 10.0.0.3/32 | 65002 | iBGP to r2, eBGP to r4   |
| r4   | 10.0.0.4/32 | 65003 | eBGP speaker             |

**Goal:** `ping 10.0.0.4 source 10.0.0.1` from r1, and the reverse.

---

## Deploy and access

```bash
sudo containerlab deploy --topo topology.yml

# EOS CLI
docker exec -it clab-bgp-basics-r1 Cli
docker exec -it clab-bgp-basics-r2 Cli
```

> Note: EOS does not require any explicit policy configuration for eBGP sessions to exchange routes (unlike FRR). Sessions come up and exchange prefixes as soon as they are configured.

---

## Step 1 — Configure eBGP between r1 and r2

On **r1**:
```
router bgp 65001
   bgp router-id 10.0.0.1
   neighbor 10.1.12.2 remote-as 65002
   !
   address-family ipv4
      neighbor 10.1.12.2 activate
      network 10.0.0.1/32
   !
```

On **r2** (eBGP side only for now):
```
router bgp 65002
   bgp router-id 10.0.0.2
   neighbor 10.1.12.1 remote-as 65001
   !
   address-family ipv4
      neighbor 10.1.12.1 activate
      network 10.0.0.2/32
   !
```

Check: `show bgp ipv4 unicast summary` on r1 — the state should reach `Established`.

---

## Step 2 — Configure iBGP between r2 and r3

**Before adding next-hop-self**, add the iBGP peer on both routers and observe the problem:

On **r2** (add to existing config):
```
router bgp 65002
   neighbor 10.1.23.2 remote-as 65002
   !
   address-family ipv4
      neighbor 10.1.23.2 activate
   !
```

On **r3**:
```
router bgp 65002
   bgp router-id 10.0.0.3
   neighbor 10.1.23.1 remote-as 65002
   !
   address-family ipv4
      neighbor 10.1.23.1 activate
      network 10.0.0.3/32
   !
```

Now check r3's BGP table:
```
show bgp ipv4 unicast
```

You will see r1's prefix (10.0.0.1/32) listed but marked as **inaccessible** (no `>` best-path marker). The next-hop is 10.1.12.1 (r1's IP), which r3 cannot reach.

**Fix — add next-hop-self on r2:**
```
router bgp 65002
   !
   address-family ipv4
      neighbor 10.1.23.2 next-hop-self
   !
```

Now r3 sees r2 (10.1.23.1) as the next-hop for r1's prefix — reachable!

---

## Step 3 — Configure eBGP between r3 and r4

On **r3** (add to existing config):
```
router bgp 65002
   neighbor 10.1.34.2 remote-as 65003
   !
   address-family ipv4
      neighbor 10.1.34.2 activate
      neighbor 10.1.34.2 next-hop-self
   !
```

On **r4**:
```
router bgp 65003
   bgp router-id 10.0.0.4
   neighbor 10.1.34.1 remote-as 65002
   !
   address-family ipv4
      neighbor 10.1.34.1 activate
      network 10.0.0.4/32
   !
```

---

## Verification

```
! Check all BGP sessions — should show 'Established' and non-zero prefixes
show bgp ipv4 unicast summary

! Full BGP table — look for 4 loopback prefixes
show bgp ipv4 unicast

! Routing table — BGP routes marked with 'B'
show ip route bgp

! End-to-end ping (run from EOS CLI)
ping 10.0.0.4 source 10.0.0.1    ! on r1
ping 10.0.0.1 source 10.0.0.4    ! on r4
```

---

## Experiments

### Try loopback-based iBGP peering (update-source)

In production, iBGP sessions use loopback addresses for resilience (session stays up if one path goes down). This requires:
1. r2 and r3 to have routes to each other's loopbacks (via a static route or IGP)
2. `update-source Loopback0` on both peers
3. `ebgp-multihop` is NOT needed for iBGP (TTL=255 by default)

Add static routes on r2 and r3 to reach each other's loopbacks:
```
! On r2:
r2(config)# ip route 10.0.0.3/32 10.1.23.2
! On r3:
r3(config)# ip route 10.0.0.2/32 10.1.23.1
```

Then change iBGP peering to use loopbacks:
```
! On r2:
router bgp 65002
   neighbor 10.0.0.3 remote-as 65002
   !
   address-family ipv4
      neighbor 10.0.0.3 activate
      neighbor 10.0.0.3 update-source Loopback0
      neighbor 10.0.0.3 next-hop-self
   !
```

### Observe iBGP split-horizon

r3 learns r1's prefix (10.0.0.1/32) from r2 via iBGP. If r3 had a third iBGP peer (r5), it would NOT re-advertise this route to r5. This is iBGP split-horizon — it prevents loops in a full-mesh iBGP network.

To see this: add a 5th container node and peer it iBGP with r3 only. r5 will not receive r1's prefix. The solution is either full-mesh iBGP (peer r5 with both r2 and r3) or a Route Reflector (see the bgp-rr lab).

---

## Troubleshooting

**Session stuck in Active**
- Confirm IP addresses and `remote-as` values are correct on both ends
- `ping 10.1.12.2` from r1 — if this fails, check interface IPs

**Prefix visible in BGP table but not in routing table**
- The next-hop is unreachable — add `next-hop-self` on the advertising iBGP peer
- `show bgp ipv4 unicast 10.0.0.1/32` — look at the Nexthop field and the 'inaccessible' note

**BGP routes not showing up on r1 from r4**
- Walk the path: does r4 have the prefix? Does r3? Does r2?
- `show bgp ipv4 unicast` on each hop and look for the missing handoff
