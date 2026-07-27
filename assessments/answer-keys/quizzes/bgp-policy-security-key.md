# Answer Key — BGP Policy & Security Topic Quiz

**Total:** 30 points

## A1 — The forwarding table gets the last word (3 points)

Routers perform longest-prefix matching in the forwarding table, so
`192.0.2.200` matches the /25 more specifically than the legitimate /24. BGP attributes
select among paths for the **same prefix**; weight or local preference on the /24 cannot
beat a different, longer prefix. (2)

A maximum-prefix limit constrains route volume and can protect the control plane from a
large leak. A one-prefix targeted hijack remains far below a reasonable limit, so the
control does not establish authorization for that route. (1)

## A2 — What RPKI proves (3 points)

1. `198.51.100.0/24` from AS 65010 is **valid**: prefix, length, and origin match. (0.5)
2. `198.51.100.0/25` from AS 65010 is **invalid**: the origin matches, but /25 exceeds
   maxLength /24. (0.5)
3. `203.0.113.0/24` is **not found**: no covering ROA was given. (0.5)
4. RPKI origin validation does not prove that the AS path is genuine, short, policy
   compliant, or free of a route leak. It authorizes the origin, not every transit hop.
   (1.5)

## B1 — Established, valid, and still rejected (8 points)

1. Transport/session formation and RTR validation both work. The received-routes view
   proves edge received the NLRI, while the local table and prefix-list show import policy
   rejected it because only `203.0.113.0/24` is permitted. RPKI state is an input to
   policy, not an automatic permit. (3)
2. Update the authoritative local IRR object for AS65020 to include the authorized
   prefix, regenerate the prefix-list, review the diff, and apply the resulting policy.
   Editing only the rendered list would be overwritten on the next generation. (2)
3. Perform an inbound soft clear/route refresh for that neighbor so stored received
   routes are re-evaluated without tearing down the session. (1)
4. Confirm `203.0.114.0/24` now appears as an accepted valid path, and test a deliberately
   unregistered prefix in received-routes that remains absent from the local table or
   shows a deny counter hit. Equivalent positive-plus-negative evidence earns full
   credit. (2)

## C1 — Customer import policy (6 points)

```text
ip prefix-list CUST-65110-IN seq 5 permit 203.0.112.0/23 le 24

route-map CUST-65110-IN permit 10
   match ip address prefix-list CUST-65110-IN
   set local-preference 150
   set community 65000:110 additive

router bgp 65000
   address-family ipv4
      neighbor 192.0.2.2 route-map CUST-65110-IN in
```

- prefix-list is bounded to the /23 and /24s only: 2
- permitting route-map matches that list: 1
- local preference 150: 1
- community with `additive`: 1
- inbound neighbor attachment, relying on the route-map's implicit deny for everything
  else: 1

`203.0.112.0/23 ge 23 le 24` is equivalent. A global permit-any catch-all defeats the
authorization requirement and loses the final two policy points.

## C2 — Aggregate without hiding contributor origin (4 points)

```text
router bgp <ASN>
   address-family ipv4
      aggregate-address 10.16.0.0/21 summary-only as-set
```

- correct aggregate and `summary-only`: 1
- `as-set` retains contributor AS information: 1
- the aggregate exists while at least one qualifying component is in the BGP table and
  withdraws when the last component disappears: 1
- suppressing all specifics reduces table size but removes more-specific steering and
  failure isolation; a partial component failure can remain hidden behind the aggregate.
  Any concrete equivalent trade-off earns 1.

## D1 — A constrained RTBH service (6 points)

A complete design contains:

- authenticate the requesting participant and accept the blackhole community only from
  its approved BGP session; (1)
- permit only exact `/32` routes inside prefixes the participant is authorized to
  originate, using IRR/RPKI and an explicit local allowlist rather than the community
  alone; (1.5)
- reject broader, unrelated, or invalid-origin routes before the RTBH exception, and
  apply maximum-route/rate controls to bound abuse; (1)
- rewrite the accepted route to a controlled discard next hop and constrain propagation
  with the documented IXP community policy; route servers must preserve the required
  community without becoming forwarding transit; (1)
- require expiry or explicit withdrawal, confirm the route disappears after the incident,
  and test ordinary reachability restoration; (0.75)
- retain the request, operator approval, route-policy counters, BGP evidence, timestamps,
  and removal evidence for audit. (0.75)

Equivalent controls earn credit when together they prove **who**, **which prefix**,
**bounded effect**, and **lifecycle**. “Trust community 65010:666” alone earns no
authorization marks.

## Remediation table

| Question | Objective | Labs |
|---|---|---|
| A1 | Longest-prefix hijacking and maximum-route limits | `bgp-prefix-security` |
| A2 | ROA fields, ROV states, and origin-only assurance | `bgp-rpki`, `bgp-prefix-security` |
| B1 | IRR source-to-policy workflow and Established-but-filtered diagnosis | `internet-peering-ixp`, `bgp-filtering` |
| C1 | Prefix-list bounds, route-map attributes, community preservation | `bgp-filtering`, `bgp-communities` |
| C2 | Aggregate activation, summary-only, AS_SET trade-offs | `bgp-aggregation` |
| D1 | RPKI/IRR-aware, scoped RTBH at a route server | `internet-peering-ixp`, `bgp-rpki` |
