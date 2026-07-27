# Answer Key — Hybrid Cloud Networking Topic Quiz

**Total:** 30 points

## A1 — Learned route versus associated path (3 points)

- Propagation makes a prefix available to a route table or routing domain; it does not
  decide which table a workload/source actually consults. (1)
- Association binds the workload/interface/source to the intended route table, while a
  source policy rule can select that table for the return flow. (1)
- Therefore a transit BGP route can exist while the workload's associated table chooses
  a direct, default, or unintended path that bypasses inspection. (1)

## A2 — Two policy layers (3 points)

- A stateful inspection policy permits a new HTTPS flow and uses connection state for
  the reverse packets; new-flow and established/related counters should both rise. (1)
- A stateless subnet ACL evaluates directions independently, so it needs an explicit
  inbound request tuple and outbound reverse tuple, including source/destination ports.
  (1)
- Either layer can deny the transaction independently; passing one does not prove the
  other or symmetric routing. (1)

## B1 — The SYN arrives, but inspection never sees the reply (8 points)

1. Trusted DNS resolves the private record, corporate routing reaches inspection, and
   inspection forwards the new SYN to App A. (2)
2. App A's source-associated table sends the reply directly to transit rather than
   through inspection. The stateful device never observes the reverse packet, so its
   established state/counter cannot complete the flow. (2)
3. Replace only table 201's corporate return route/association so
   source `10.81.10.10` uses the inspection next hop; do not add a reachability-only host
   route in the wrong table. (2)
4. Use source-aware `route get` to prove table 201 selects inspection, then capture or
   inspect counters on both inspection directions for a fresh session. (2)

## C1 — Design a redundant inspected hybrid path (10 points)

- Establish both edge attachments and advertise only the approved corporate aggregate;
  set deterministic preference for the primary while retaining the backup path. (2)
- Propagate only explicit application/DNS prefixes through transit and avoid broad cloud
  defaults or cross-application leakage. (2)
- Associate workload return routes with the inspection next hop and prove new plus
  established state in both directions. (2)
- Publish private DNS through trusted-source views/resolver paths while untrusted sources
  receive no private record. (1)
- Validate edge BGP selection, transit RIB/FIB, workload source-table lookup, inspection
  counters/captures, DNS view, and application TLS result. (2)
- Fail the primary attachment and test a fresh session through the backup; existing-flow
  survival is a separate stateful-HA question and must not be assumed. (1)

## D1 — An acquisition brings overlapping space (6 points)

- Advertising the acquired `10.80.10.0/24` makes the same destination represent two
  domains in shared transit, risking route hijack, ambiguity, and incorrect return paths.
  (2)
- Renumbering gives durable uniqueness but costs migration effort; non-transitive
  isolation is safest while connectivity is unnecessary; narrowly scoped NAT can bridge
  specific services but adds state, logging, and troubleshooting complexity. (2)
- Select based on required communication and duration, then verify the conflicting route
  is absent from shared transit (or uniquely translated), genuine corporate routing
  remains selected, only approved services cross the boundary, and both return paths and
  negative isolation tests succeed. (2)

## Remediation

| Weak area | Review |
|---|---|
| Attachments, route association/propagation, inspection symmetry, DNS views, and overlap | `labs/cloud-hybrid-networking/` |
