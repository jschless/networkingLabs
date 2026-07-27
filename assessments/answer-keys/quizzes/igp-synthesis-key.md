# Answer Key — Interior Gateway Protocols Synthesis Quiz

**Total:** 40 points

This key allows defensible alternatives in the design questions. Award marks for matching
mechanisms to requirements, not for selecting the same protocol name as the model.

## A1 — Three ways to describe a network (4 points)

A complete comparison includes:

- **OSPF:** exchanges typed LSAs describing routers, networks, summaries, and externals.
  Routers build a per-area link-state database and run Dijkstra SPF; ABRs connect area
  views through area 0. (1)
- **EIGRP:** exchanges routes and metrics with neighbors rather than a domain-wide LSDB.
  DUAL uses successor, feasible-distance, reported-distance, and query/reply state to
  maintain loop-free paths. (1)
- **IS-IS:** floods LSPs containing extensible TLVs. Routers build Level-1 and/or Level-2
  link-state databases and run SPF at each active level. (1)
- A meaningful synthesis point: OSPF and IS-IS calculate from flooded topology state,
  while EIGRP's loop-free convergence depends on neighbor-reported distance and bounded
  diffusing computation. (1)

## A2 — Alternate paths are not equivalent (4 points)

- **OSPF:** installs equal-cost paths. A higher-cost path is normally not used for
  forwarding; after failure, a new SPF calculation selects it unless an independent
  fast-reroute feature exists. (1)
- **EIGRP:** a higher-cost path whose RD satisfies the feasibility condition can remain a
  feasible successor and be promoted immediately. `variance` can also install a feasible
  unequal-cost path before failure and share traffic inversely by metric. (1.5)
- **IS-IS:** like OSPF in the labs, it installs ECMP paths rather than arbitrary
  unequal-cost paths. A higher-cost path becomes best after SPF recalculation; metrics
  and the overload bit influence selection but do not create EIGRP-style variance. (1)
- Explicitly distinguishing installed unequal-cost forwarding, precomputed backup, and
  post-failure recomputation: 0.5

## B1 — The route came home (10 points)

1. `10.50.0.0/16` begins as an internal EIGRP route and enters OSPF at br1, where it is
   marked tag 200. br2 loses its direct EIGRP path but still learns the prefix across the
   OSPF core as `O E2`. Its unrestricted OSPF-to-EIGRP route-map redistributes that route
   back into EIGRP, where another router sees it as `D EX`. (3)
2. The route-map has no deny for tag 200 before its permit. It therefore reintroduces an
   EIGRP-originated route into EIGRP. During failures this can create feedback,
   persistent/suboptimal detours, or a forwarding loop between redistribution points.
   (2)
3. Before any permit, br2 must deny OSPF routes carrying tag 200 from
   OSPF-to-EIGRP redistribution. It may then permit approved OSPF-origin routes, set the
   EIGRP seed metric, and preferably tag them 100. (2)
4. Administrative distance decides which route enters one router's RIB; it does not
   preserve origin or stop another border from redistributing a route later. A seed
   metric makes an external route usable and influences preference, but likewise carries
   no loop-prevention rule. Both can change during failure, exactly when feedback appears.
   (2)
5. Accept one: the EIGRP-domain topology/RIB no longer contains `D EX` for the
   EIGRP-origin prefix; redistribution counters show it denied; route-map counters hit
   the tag-200 deny; or controlled failure testing shows the route withdraws rather than
   returning. (1)

## C1 — Select for the requirements (6 points)

1. **OSPF** is the model choice: it is an open standard, has familiar area/ABR design,
   supports IPv4 and IPv6 through OSPFv2/v3, and is widely operated across vendors.
   One point for the choice, one for tying at least two stated requirements to it. (2)
2. **EIGRP** is the model choice: variance supports feasible unequal-cost paths, while
   EIGRP stub and summarization bound query scope in a large hub-and-spoke design.
   Single-platform support removes the major interoperability objection. (2)
3. **IS-IS** is the model choice: its TLV design carries extensions such as SR
   information cleanly, and adjacency/control-plane operation is not dependent on IP
   interface addressing. Its L1/L2 hierarchy also fits a provider core. (2)

A different protocol can earn up to two points per case only when the candidate addresses
the constraints rather than ignoring them. For example, “OSPF because everyone knows it”
does not satisfy case 2's unequal-cost requirement.

## C2 — Write the boundary policy (6 points)

Model pseudocode:

```text
policy EIGRP_TO_OSPF
  deny  if route-tag == 100
  permit if prefix in APPROVED_EIGRP
    set route-tag 200
  deny all

policy OSPF_TO_EIGRP
  deny  if route-tag == 200
  permit if prefix in APPROVED_OSPF
    set route-tag 100
    set eigrp-seed-metric <bandwidth delay reliability load mtu>
  deny all
```

Apply the first policy to EIGRP-to-OSPF redistribution and the second to
OSPF-to-EIGRP redistribution on **both** border routers.

Point allocation:

- deny tag 100 before EIGRP-to-OSPF permit: 1
- approved-prefix allowlist and tag 200 in that direction: 1
- explicit default deny in that direction: 1
- deny tag 200 before OSPF-to-EIGRP permit: 1
- approved-prefix allowlist, tag 100, and explicit default deny in that direction: 1
- explicit EIGRP seed metric and application on both borders: 1

Equivalent tag values do not earn full credit because the question assigns 100 and 200.
Policies that set tags but never reject returning tags solve only half the problem.

## D1 — Both adjacencies are healthy (10 points)

### Model narrative

1. The leading class is route feedback or inconsistent policy at the two redistribution
   points, exposed when br1's preferred path disappeared. A plausible alternative is a
   forwarding/return-path policy such as an ACL, PBR rule, or stale FIB on only one
   initiation direction. (2)
2. A strong ordered evidence set is:
   - inspect the affected destination in the data-center source router's RIB and FIB,
     establishing next hop, protocol origin, and whether forwarding agrees with routing;
   - inspect the same prefix and its tag on br1 and br2 in both protocol topology
     views, showing where an internal route became external or re-entered;
   - inspect redistribution route-maps, tag matches, prefix filters, seed metrics, and
     counters on both borders, testing the feedback hypothesis;
   - use hop-by-hop forwarding evidence such as traceroute, interface counters, or packet
     capture during a data-center-initiated attempt, locating the actual br1/br2 loop.

   Other orders earn full credit when each command/view has a stated falsification
   purpose. At least one origin/tag check and one FIB/data-plane check are mandatory.
   (4)
3. Add symmetric, deny-before-permit tag policy at both borders: reject
   EIGRP-origin tag 200 on OSPF-to-EIGRP and OSPF-origin tag 100 on
   EIGRP-to-OSPF, then allow only approved prefixes with explicit metrics. Remove only
   the leaked/feedback route state needed for policy to take effect; do not redesign
   metrics during the incident. (2)
4. Initiate application or at least source-specific reachability tests from a branch to
   the data center and from the data center to the branch, verify the return path, and
   repeat with each redistribution link failed in turn. (1)
5. Rejected masks include adding a broad static route, lowering administrative distance
   until one route “wins,” shutting a redundant border, or filtering the symptom prefix
   without an origin policy. Each may stop the immediate loop while preserving feedback,
   removing redundancy, or creating a future black hole. (1)

## Remediation table

| Question | Objective | Labs |
|---|---|---|
| A1 | Link-state flooding versus DUAL | `ospf-multiarea`, `eigrp-basics`, `isis-basics` |
| A2 | ECMP, feasible successors, variance, SPF reconvergence | `eigrp-basics`, `eigrp-variance`, `isis-basics`, `ospf-multiarea` |
| B1, C2, D1 | Safe mutual redistribution and route tags | `redistribution-tags`, `ospf-bgp-redist`, `debug-ospf-bgp-redist` |
| C1.1 | OSPF area design and OSPFv3 | `ospf-multiarea`, `ipv6-ospf3` |
| C1.2 | EIGRP variance and query containment | `eigrp-variance`, `eigrp-stub` |
| C1.3 | IS-IS TLVs, hierarchy, and provider-core use | `isis-basics`, `isis-multiarea`, `mpls-sr-isis-bgp` |
