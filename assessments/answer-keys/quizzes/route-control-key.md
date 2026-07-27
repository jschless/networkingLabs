# Answer Key — Route Control & Redistribution Topic Quiz

**Total:** 30 points

## A1 — PBR is outside the RIB (3 points)

Interface PBR examines packets as they arrive, before the ordinary destination-only RIB
lookup. A matching route-map can force a next hop even when it is not the RIB's selected
path, which is both its capability and its black-hole risk. Router-generated packets do
not arrive on that interface and therefore bypass interface PBR; EOS uses
`ip local policy route-map <MAP>` for them. (3)

Award one point for order/forced next hop, one for the risk/RIB independence, and one for
local-traffic scope plus the correct mechanism.

## A2 — What a probe adds (3 points)

An ordinary floating static takes over when the preferred route disappears, commonly
because the interface or immediate next hop is down. A tracked primary is withdrawn when
an IP SLA operation fails, so it can detect an upstream path or service failure while the
local Ethernet and next-hop adjacency remain healthy. A poor target—one filtered,
rate-limited, unstable, or reachable only through the backup—can mark a usable primary
down or create oscillation. (3)

## B1 — The RIB failed over; the user did not (8 points)

1. PBR on Ethernet2 matches host-b before the RIB lookup and still forces dead next hop
   `10.0.2.2`. The backup default is used only for packets that fall through to normal
   routing. (2)
2. Two defensible repairs include:
   - add `set ip next-hop verify`, so the forced next hop is used only while it is
     reachable in the RIB and unmatched/unusable policy falls through; or
   - make the PBR decision depend on tracked/recursive reachability, or remove this PBR
     rule and express the preference through convergent routing.

   The first validates next-hop presence; a tracked design can test a farther target but
   adds probe dependencies. (2)
3. The backup default is already being bypassed by the PBR match. Deleting it cannot make
   the forced next hop usable and would damage fallback for all normal-routed traffic.
   (1)
4. Check `show ip policy` for the intended interface binding, `show route-map` and ACL
   counters for the actual match/fallback, and run a traceroute or application test from
   host-b proving traffic now exits ISP-A while ISP-B is down. Restoring ISP-B and proving
   intended preference returns is also valid. (3)

## C1 — Tracked primary and floating backup (6 points)

```text
ip sla 1
   icmp-echo 10.99.0.1 source-interface Ethernet1
   frequency 5
ip sla schedule 1 life forever start-time now

track 1 ip sla 1 reachability

ip route 0.0.0.0/0 10.0.1.2 5 track 1
ip route 0.0.0.0/0 10.0.2.2 200
```

- SLA operation, target, and source interface: 1.5
- five-second frequency: 0.5
- forever/immediate schedule: 1
- reachability track binding: 1
- tracked primary with next hop and AD 5: 1
- untracked floating backup with next hop and AD 200: 1

The source-interface spelling used by the deployed platform may render as `eth1`;
accept the platform-consistent equivalent.

## C2 — Source-based PBR with reachability protection (4 points)

```text
ip access-list extended HOST-B-SOURCE
   permit ip 10.20.0.0/24 any

route-map PBR-ISP-B permit 10
   match ip address HOST-B-SOURCE
   set ip next-hop 10.0.2.2
   set ip next-hop verify

interface Ethernet2
   ip policy route-map PBR-ISP-B
```

- exact source ACL: 1
- permitting route-map and match: 1
- next hop plus verification/fallback behavior: 1
- inbound interface attachment: 1

## D1 — One boundary, one convention (6 points)

1. EIGRP-to-OSPF must first deny tag 100, because those routes began in OSPF, then permit
   approved routes and set tag 200. OSPF-to-EIGRP must first deny tag 200, then permit
   approved routes, set tag 100, and supply a valid EIGRP seed metric. (3)
2. A route can cross at one ASBR and return at the other, so one unprotected boundary
   defeats the domain-wide convention. Administrative distance selects among routes in
   one RIB; it neither records origin nor prevents a different ASBR from redistributing
   the selected route later. (2)
3. OSPF's external database should contain EIGRP-origin routes with tag 200 but no
   tag-100 routes fed back from EIGRP; the EIGRP-to-OSPF map's tag-100 deny counter should
   increment. EIGRP's external topology should contain OSPF-origin routes with tag 100
   but no returned tag-200 routes; the OSPF-to-EIGRP tag-200 deny counter should
   increment. Equivalent protocol-specific route/tag evidence for both sides earns the
   point. (1)

## Remediation table

| Question | Objective | Labs |
|---|---|---|
| A1, B1, C2 | PBR order, scope, reachability, and verification | `route-maps-pbr` |
| A2, C1 | IP SLA, object tracking, and floating statics | `ip-sla-tracking` |
| D1 | Symmetric tag-based redistribution loop prevention | `redistribution-tags`, `ospf-bgp-redist`, `debug-ospf-bgp-redist` |
