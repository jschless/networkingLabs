# OSPF ↔ BGP Redistribution — Practice Lab

Configure mutual redistribution between an OSPF domain and a BGP AS.
IP addressing is pre-configured on every node. You implement all
routing protocols and redistribution.

---

## Topology

```
  [r1] ----OSPF area 0---- [asbr] ----eBGP---- [bgp1] ----iBGP---- [bgp2]
                           AS65100              AS65200
```

### Link addressing

| Link          | Subnet        | Left side        | Right side       | Protocol  |
|---------------|---------------|------------------|------------------|-----------|
| r1 — asbr     | 10.0.12.0/30  | 10.0.12.1 (r1)   | 10.0.12.2 (asbr) | OSPF a0   |
| asbr — bgp1   | 10.0.23.0/30  | 10.0.23.1 (asbr) | 10.0.23.2 (bgp1) | eBGP      |
| bgp1 — bgp2   | 10.0.34.0/30  | 10.0.34.1 (bgp1) | 10.0.34.2 (bgp2) | iBGP      |

### Node reference

| Node | Loopback     | ASN   | Role                               |
|------|--------------|-------|------------------------------------|
| r1   | 10.0.0.1/32  | —     | OSPF-only router                   |
| asbr | 10.0.0.2/32  | 65100 | ASBR — redistributes OSPF ↔ BGP   |
| bgp1 | 10.0.0.3/32  | 65200 | eBGP + iBGP transit                |
| bgp2 | 10.0.0.4/32  | 65200 | BGP end-router                     |

**Goal:** `ping 10.0.0.4 source 10.0.0.1` succeeds from r1's vtysh, and
`ping 10.0.0.1 source 10.0.0.4` succeeds from bgp2's vtysh.

---

## Deploy and access

```bash
# Deploy the lab
sudo containerlab deploy --topo topology.yml

# Open the FRR CLI on any node
sudo containerlab exec --topo topology.yml --node asbr --cmd "vtysh"

# Or via docker
docker exec -it clab-ospf-bgp-redist-asbr vtysh
```

---

## Step 1 — OSPF on r1 and asbr

Configure OSPF in area 0 on both nodes. Loopbacks should be passive
(advertised but no hellos sent).

### r1

```
interface lo
 ip ospf passive
 ip ospf area 0
!
interface eth1
 ip ospf area 0
!
router ospf
 ospf router-id 10.0.0.1
```

### asbr

```
interface lo
 ip ospf passive
 ip ospf area 0
!
interface eth1
 ip ospf area 0
!
router ospf
 ospf router-id 10.0.0.2
```

Verify on asbr: `show ip ospf neighbor` should show r1 in Full state.

---

## Step 2 — eBGP between asbr and bgp1

### asbr (AS 65100)

```
router bgp 65100
 no bgp ebgp-requires-policy
 neighbor 10.0.23.2 remote-as 65200
 address-family ipv4 unicast
  neighbor 10.0.23.2 activate
```

### bgp1 (AS 65200) — also configure iBGP to bgp2 here

```
router bgp 65200
 no bgp ebgp-requires-policy
 neighbor 10.0.23.1 remote-as 65100
 neighbor 10.0.34.2 remote-as 65200
 address-family ipv4 unicast
  neighbor 10.0.23.1 activate
  neighbor 10.0.34.2 activate
  neighbor 10.0.34.2 next-hop-self
```

`next-hop-self` is critical: without it, bgp2 receives prefixes with
a next-hop of 10.0.23.1 (asbr), which bgp2 cannot reach.

### bgp2 (AS 65200)

```
router bgp 65200
 no bgp ebgp-requires-policy
 neighbor 10.0.34.1 remote-as 65200
 address-family ipv4 unicast
  neighbor 10.0.34.1 activate
```

Verify: `show bgp ipv4 unicast summary` on asbr and bgp1 should show
Established state.

---

## Step 3 — Redistribute OSPF into BGP (at asbr)

This makes OSPF-learned prefixes (r1's loopback, etc.) visible in BGP.

```
router bgp 65100
 address-family ipv4 unicast
  redistribute ospf
```

Check on bgp2: `show bgp ipv4 unicast` — you should see 10.0.0.1/32
and 10.0.0.2/32 with bgp1 (10.0.34.1) as next-hop.

---

## Step 4 — Redistribute BGP into OSPF (at asbr)

This makes BGP-learned prefixes (bgp1/bgp2 loopbacks, etc.) visible
in OSPF as Type-5 external LSAs.

```
router ospf
 redistribute bgp
```

Check on r1: `show ip route ospf` — you should see 10.0.0.3/32 and
10.0.0.4/32 marked as `OE2` (external type-2).

---

## Verification

```
! On asbr — confirm both protocols have neighbours
show ip ospf neighbor
show bgp ipv4 unicast summary

! On asbr — see what is being redistributed
show ip bgp                    ! BGP table (should include OSPF prefixes)
show ip route ospf             ! OSPF routes (should include BGP prefixes)

! On bgp2 — confirm OSPF prefixes arrived via BGP
show bgp ipv4 unicast
show ip route

! End-to-end ping — run from vtysh
ping 10.0.0.4 source 10.0.0.1   ! on r1
ping 10.0.0.1 source 10.0.0.4   ! on bgp2
```

---

## Experiments

### Use a route-map to tag redistributed routes

Instead of blindly redistributing all OSPF routes, apply a route-map
that sets a BGP community on redistributed prefixes.

On asbr:
```
route-map OSPF-TO-BGP permit 10
 set community 65100:100
!
router bgp 65100
 address-family ipv4 unicast
  redistribute ospf route-map OSPF-TO-BGP
```

Check `show bgp ipv4 unicast` on bgp1 — the community should appear.

### Filter specific prefixes during redistribution

Suppress the transit subnet (10.0.12.0/30) from being redistributed
into BGP using a prefix-list:

```
ip prefix-list NO-TRANSIT seq 5 deny 10.0.12.0/30
ip prefix-list NO-TRANSIT seq 10 permit 0.0.0.0/0 le 32
!
route-map OSPF-TO-BGP permit 10
 match ip address prefix-list NO-TRANSIT
!
router bgp 65100
 address-family ipv4 unicast
  redistribute ospf route-map OSPF-TO-BGP
```

### Redistribute connected instead of BGP into OSPF

On asbr, replace `redistribute bgp` with `redistribute connected`
in the OSPF process. Observe how the metric and LSA type differ.

---

## Troubleshooting

**OSPF neighbours not forming**
- `show ip ospf interface eth1` — confirm OSPF is enabled and area matches
- `show ip ospf neighbor` — check state; Init means hellos arriving but not bidirectional

**BGP session stuck in Active**
- `show bgp ipv4 unicast summary` — Active means TCP not established
- Confirm the peer IP and remote-as are correct on both sides
- `ping 10.0.23.2` from asbr to confirm L3 reachability

**Prefixes not appearing after redistribution**
- `show bgp ipv4 unicast` on asbr — if no OSPF prefixes, check `redistribute ospf` is under `address-family ipv4 unicast`
- `show ip route bgp` on r1 — if empty, check `redistribute bgp` is in the OSPF process
- `show ip ospf database external` on r1 — Type-5 LSAs from asbr should appear

**bgp2 has routes but next-hop is unreachable**
- This is the `next-hop-self` issue — add `neighbor 10.0.34.2 next-hop-self` on bgp1
- Without it, bgp2 tries to reach 10.0.23.1 (asbr) which is not in bgp2's routing table

**Routes show in table but ping fails**
- Check return path: does bgp2 have a route back to 10.0.0.1?
- Verify `redistribute bgp` is configured in OSPF on asbr
- Use `traceroute` to isolate where packets are dropped
