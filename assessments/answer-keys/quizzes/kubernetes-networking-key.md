# Answer Key — Kubernetes Service Networking Topic Quiz

**Total:** 30 points

## A1 — Turn a Service into a route (3 points)

- `BGPPeer` defines the speaker-to-router neighbor/AS relationship;
  `IPAddressPool` supplies assignable service addresses; and `BGPAdvertisement` tells
  MetalLB to announce addresses from the referenced pool. (2)
- Each allocated service VIP is advertised as a /32 so routing follows that individual
  service's active speakers/endpoints without attracting unused pool addresses or
  coupling unrelated services. (1)

## A2 — Cluster versus Local (3 points)

- `Cluster` permits any advertising node to forward to an endpoint on another node,
  maintaining broad advertisement/load distribution but commonly SNATing/hiding the
  original client and adding an inter-node hop. (1)
- `Local` preserves client source and avoids cross-node service forwarding, but a node
  advertises only while it has a local ready endpoint. (1)
- Pod placement therefore changes fabric next hops under `Local`; endpoint and BGP route
  convergence become coupled. (1)

## B1 — The service has an address but the fabric has no route (8 points)

1. The controller allocated a VIP and both node-to-ToR BGP sessions are Established.
   Zero prefixes and no /32 show allocation is not being advertised into the fabric.
   (3)
2. The most likely fault is a missing `BGPAdvertisement` or one that does not reference
   the `services` pool. (2)
3. Verify speaker logs/BGP advertised routes and nonzero ToR prefix counts; confirm the
   ToR installs the VIP /32 with the expected next hop(s); and reach the VIP from an
   external client while checking the selected backend/endpoint. (3)

## C1 — Preserve client IP without creating a one-node service (10 points)

- Run at least one ready replica on each of at least two ingress nodes using
  anti-affinity/topology spread and account for maintenance/disruption budgets. (2)
- Under `Local`, only nodes with local ready endpoints advertise the VIP; verify the two
  intended speakers announce the same /32. (2)
- Configure compatible eBGP neighbors and `maximum-paths` on the ToR so both equal paths
  install in the FIB. (2)
- Confirm the application sees the real client source and that flows distribute across
  both node next hops without cross-node forwarding. (1)
- Remove one pod/node and prove its advertisement withdraws while the surviving local
  endpoint continues serving; restore placement and ECMP. (2)
- Acknowledge the short risk window where endpoint readiness and BGP withdrawal are not
  simultaneous; readiness, graceful termination, and fast speaker convergence limit
  blackholing. (1)

## D1 — Route present, request hangs (6 points)

Award 1 point for each boundary:

1. Verify the client route/default and bidirectional reachability to the VIP pool.
2. Inspect the ToR RIB/FIB and identify the exact node next hop selected for a test flow.
3. Confirm BGP speaker session/advertisement state on that node rather than only the ToR.
4. Check Service selectors, ready EndpointSlices/endpoints, and
   `externalTrafficPolicy`.
5. Inspect node forwarding/service implementation and packet captures before/after the
   node boundary.
6. Verify pod readiness, listener, policy, and response path. A /32 proves only fabric
   reachability to a node, not a ready endpoint or working application.

## Remediation

| Weak area | Review |
|---|---|
| MetalLB objects, ToR peering, ECMP, service policy, endpoints, and VIP troubleshooting | `labs/k8s-fabric/` |
