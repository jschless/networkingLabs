# BGP Path Selection — Practice Lab

A dual-homed topology with two ISP routers lets you manipulate every major BGP path selection attribute in order. Start with a working base config, then apply each attribute and observe which path becomes preferred.

---

## Topology

```
          [isp1] (AS65100)
         /        \
    [ce1]          [ce2]
   (AS65001)      (AS65002)
         \        /
          [isp2] (AS65100)
```

Two paths between ce1 and ce2: via isp1 or via isp2. Both ISPs are in the same AS (AS65100), peered with iBGP.

### Link addressing

| Link        | Subnet       | Left      | Right     |
|-------------|--------------|-----------|-----------|
| ce1 — isp1  | 10.1.11.0/30 | 10.1.11.1 | 10.1.11.2 |
| ce1 — isp2  | 10.1.12.0/30 | 10.1.12.1 | 10.1.12.2 |
| isp1 — isp2 | 10.1.99.0/30 | 10.1.99.1 | 10.1.99.2 |
| isp1 — ce2  | 10.1.21.0/30 | 10.1.21.1 | 10.1.21.2 |
| isp2 — ce2  | 10.1.22.0/30 | 10.1.22.1 | 10.1.22.2 |

### Node reference

| Node | Loopback    | ASN   | Role                       |
|------|-------------|-------|----------------------------|
| ce1  | 10.0.0.1/32 | 65001 | Dual-homed customer A      |
| isp1 | 10.0.0.2/32 | 65100 | ISP router (upper path)    |
| isp2 | 10.0.0.3/32 | 65100 | ISP router (lower path)    |
| ce2  | 10.0.0.4/32 | 65002 | Dual-homed customer B      |

---

## Deploy and access

```bash
sudo containerlab deploy --topo topology.yml
docker exec -it clab-bgp-path-selection-ce1 vtysh
```

---

## Step 1 — Base configuration (all routers)

Configure BGP sessions and advertise loopbacks. After this step, both paths should work and traffic should flow.

### ce1 (AS 65001)
```
router bgp 65001
 no bgp ebgp-requires-policy
 bgp router-id 10.0.0.1
 neighbor 10.1.11.2 remote-as 65100
 neighbor 10.1.12.2 remote-as 65100
 address-family ipv4 unicast
  neighbor 10.1.11.2 activate
  neighbor 10.1.12.2 activate
  network 10.0.0.1/32
```

### isp1 (AS 65100)
```
router bgp 65100
 no bgp ebgp-requires-policy
 bgp router-id 10.0.0.2
 neighbor 10.1.11.1 remote-as 65001
 neighbor 10.1.99.2 remote-as 65100
 neighbor 10.1.21.2 remote-as 65002
 address-family ipv4 unicast
  neighbor 10.1.11.1 activate
  neighbor 10.1.99.2 activate
  neighbor 10.1.99.2 next-hop-self
  neighbor 10.1.21.2 activate
  network 10.0.0.2/32
```

### isp2 (AS 65100)
```
router bgp 65100
 no bgp ebgp-requires-policy
 bgp router-id 10.0.0.3
 neighbor 10.1.12.1 remote-as 65001
 neighbor 10.1.99.1 remote-as 65100
 neighbor 10.1.22.2 remote-as 65002
 address-family ipv4 unicast
  neighbor 10.1.12.1 activate
  neighbor 10.1.99.1 activate
  neighbor 10.1.99.1 next-hop-self
  neighbor 10.1.22.2 activate
  network 10.0.0.3/32
```

### ce2 (AS 65002)
```
router bgp 65002
 no bgp ebgp-requires-policy
 bgp router-id 10.0.0.4
 neighbor 10.1.21.1 remote-as 65100
 neighbor 10.1.22.1 remote-as 65100
 address-family ipv4 unicast
  neighbor 10.1.21.1 activate
  neighbor 10.1.22.1 activate
  network 10.0.0.4/32
```

Verify base: `show bgp ipv4 unicast 10.0.0.4/32` on ce1 — should show two paths, one marked `>` as best.

---

## BGP path selection order

BGP picks the best path by walking this list top-to-bottom, stopping when one path wins:

1. **Weight** — highest wins (Cisco-only, local to router, not advertised)
2. **Local-Preference** — highest wins (AS-wide via iBGP, default 100)
3. **Locally originated** — prefer routes originated by this router
4. **AS-path length** — shortest wins
5. **Origin** — IGP (i) < EGP (e) < incomplete (?)
6. **MED** — lowest wins (advisory, compared only between paths from same AS)
7. **eBGP over iBGP** — prefer eBGP-learned paths
8. **IGP metric to next-hop** — lowest wins
9. **Oldest eBGP path** (tiebreaker)
10. **Router-ID** — lowest wins (final tiebreaker)

---

## Experiment 1 — Weight (outbound preference on ce1)

Weight is Cisco-proprietary and local to the router. Highest weight wins. Not advertised.

On **ce1** — prefer isp1 for outbound:
```
router bgp 65001
 neighbor 10.1.11.2 weight 200
 neighbor 10.1.12.2 weight 100
```

After `clear ip bgp * soft`, check:
```
show bgp ipv4 unicast 10.0.0.4/32
```
The path via isp1 (10.1.11.2) should now show `weight 200` and be selected (`>`).

---

## Experiment 2 — Local-Preference (AS-wide outbound preference)

Local-pref is carried in iBGP updates and is visible to the entire AS. Highest wins (default 100).

On **isp1** — set high local-pref for prefixes received from ce1:
```
route-map LP-CE1-HIGH permit 10
 set local-preference 200
!
router bgp 65100
 neighbor 10.1.11.1 route-map LP-CE1-HIGH in
```

This tells isp2 (via iBGP) to prefer isp1's path when exiting toward ce1's prefix. Check on isp2:
```
show bgp ipv4 unicast 10.0.0.1/32
```
The path received from isp1 should show `localpref 200` and be selected.

After experimenting, remove the route-map: `no neighbor 10.1.11.1 route-map LP-CE1-HIGH in`

---

## Experiment 3 — AS-path prepending (influence inbound traffic)

AS-path prepending makes a path look longer, making it less preferred by other ASes. Used to influence which ISP receives inbound traffic.

On **ce1** — make the path via isp2 look longer (so AS65100 prefers isp1 for inbound to ce1):
```
route-map PREPEND-ISP2 permit 10
 set as-path prepend 65001 65001
!
router bgp 65001
 address-family ipv4 unicast
  neighbor 10.1.12.2 route-map PREPEND-ISP2 out
```

Check on isp2:
```
show bgp ipv4 unicast 10.0.0.1/32
```
The AS-path for ce1's prefix should now show `65001 65001 65001` (original + 2 prepends). isp2 will prefer to route toward isp1 for traffic destined to ce1.

---

## Experiment 4 — MED (advisory metric for inbound)

MED (Multi-Exit Discriminator) is sent to a neighbouring AS to suggest which entry point to use. It is only compared between paths that were learned from the **same neighbouring AS** — so it is a weaker influence than local-pref.

On **ce1** — advertise a low MED to isp1 and high MED to isp2:
```
route-map MED-LOW permit 10
 set metric 10
!
route-map MED-HIGH permit 10
 set metric 200
!
router bgp 65001
 address-family ipv4 unicast
  neighbor 10.1.11.2 route-map MED-LOW out
  neighbor 10.1.12.2 route-map MED-HIGH out
```

Check on isp1 and isp2:
```
show bgp ipv4 unicast 10.0.0.1/32
```
Look at the `metric` column — but note: MED is only compared when both paths come from the same AS. isp1 and isp2 each receive the prefix directly from ce1 (AS65001), so the MED comparison would happen if they're comparing paths to the same prefix from the same AS.

---

## Verification commands

```
! All paths for a prefix with full attribute detail
show bgp ipv4 unicast 10.0.0.1/32

! Summary — sessions and prefix counts
show bgp ipv4 unicast summary

! Routing table (only best path installed)
show ip route bgp

! Force re-evaluation after config change
clear ip bgp * soft
```

---

## Troubleshooting

**Two paths visible but neither wins decisively**
- Check Weight first (must be set locally, not in route-map in)
- Then Local-Pref (check it's being set on the inbound route-map, not outbound)

**Route-map not taking effect**
- `clear ip bgp * soft` to re-process routes without dropping sessions
- `show route-map <name>` to verify match/set clauses

**MED not being compared**
- MED is only compared between paths from the same neighbouring AS
- If the two paths come from different ASes, MED is skipped (use `bgp always-compare-med` to override — but this is rarely used in production)

**iBGP session between isp1 and isp2 not working**
- Check `next-hop-self` is configured — without it, iBGP-advertised routes have external next-hops that may be unreachable
