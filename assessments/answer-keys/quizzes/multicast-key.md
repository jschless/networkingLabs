# Answer Key — Enterprise Multicast Topic Quiz

**Total:** 20 points

## A1 — Build the forwarding state (4 points)

1. IGMP communicates receiver membership for a group to the local multicast router. (1)
2. PIM forms router adjacencies and builds/prunes multicast distribution trees between
   routed segments. (1)
3. In sparse mode, the RP supplies the shared-tree meeting point for receiver joins and
   source registration before or instead of shortest-path-tree operation. (1)
4. An `(S,G)` or `(*,G)` entry records the incoming/RPF interface and outgoing-interface
   list. The RPF check accepts traffic only when it arrives on the interface unicast
   routing uses back toward the source or RP, as appropriate. (1)

## B1 — Local receivers work, remote receivers fail (6 points)

1. Receiver membership on `dist3` and its immediate PIM adjacency are healthy. The
   `(*,G)` entry cannot build upstream because the configured RP has no unicast route,
   leaving the incoming interface Null. (3)
2. A receiver on the source VLAN can receive the local Layer-2 multicast without a
   routed PIM tree or reachable RP. (1)
3. Restore unicast reachability to RP `10.255.0.1` without replacing it with an
   unrelated RP. Then verify a valid RPF/incoming interface in `show ip mroute` and the
   remote receiver's actual UDP delivery; PIM/RP state may be used as the second state
   check. (2)

## C1 — Remove the single-RP dependency (5 points)

Award full credit for either defensible model:

- **Anycast-RP:** advertise the same RP address from both cores, make unicast routing
  select the nearest surviving core, and synchronize source-active/register state using
  the platform's Anycast-RP mechanism, commonly MSDP or PIM-based state sharing. (3)
- **BSR/candidate-RP:** use redundant bootstrap and candidate RPs so routers dynamically
  learn a surviving group-to-RP mapping rather than depending on one static RP. (3)

For either choice:

- Source and receiver routers must retain the RP mapping/state through a failure. (1)
- Healthy unicast routing to the selected RP and source remains required for RPF and
  tree construction. (1)

## D1 — Trace a missing multicast flow (5 points)

Award 1 point for each ordered boundary:

1. Prove the application is listening/joined and inspect IGMP membership on the
   receiver-facing router.
2. Walk PIM neighbors hop by hop toward the source/RP.
3. Inspect `(*,G)` and `(S,G)` entries, incoming interface, and outgoing-interface list.
4. Compare the RPF interface/neighbor with the unicast route to the RP or source and
   verify RP mapping/reachability.
5. Confirm the source is transmitting the correct group, UDP port, interface, and
   nonzero TTL, using a capture at source and receiver boundaries.

Changing random TTLs or RP addresses without locating the missing state does not earn
method credit.

## Remediation

| Weak area | Review |
|---|---|
| IGMP, PIM-SM, RP behavior, RPF state, and multicast troubleshooting | `labs/enterprise-multicast/` |
