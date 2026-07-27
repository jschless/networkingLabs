# Answer Key — Routed Network Foundations Topic Quiz

**Total:** 20 points

## A1 — From link to learned route (4 points)

- Physical/link state only proves local interface/carrier; correct addressing and subnet
  supply IP adjacency. (1)
- OSPF Hello compatibility creates a neighbor, and Full indicates LSDB synchronization,
  not application success. (1)
- SPF/RIB selection installs learned reachability, which must then resolve into the FIB
  and Layer-2 next hop. (1)
- Bidirectional sourced traffic proves forward plus return forwarding and endpoint
  behavior. (1)

## B1 — The far side shut its interface (6 points)

- Because r1's local veth/carrier remains up, it does not receive an immediate local
  link-down event and initially retains the neighbor. (2)
- Missing Hellos age the neighbor at the dead interval, normally 40 seconds with
  10-second Hellos in this lab. (2)
- After expiry, the adjacency and routes learned only through r2 are removed; verify
  timestamped neighbor events, local interface still up, Hello absence, and RIB change.
  Immediate local interface down would instead indicate carrier/local shutdown. (2)

## C1 — Verify a two-router deployment (5 points)

Award 1 point for each ordered boundary:

1. Both containers and expected link exist.
2. Interfaces are up with correct /30 addresses.
3. OSPF is enabled with compatible parameters and the neighbor is Full.
4. Expected connected and learned routes are installed with the right next hop.
5. A sourced bidirectional ping succeeds; each earlier state is necessary but does not
   prove the next protocol or return path.

## D1 — Make the lab result reproducible (5 points)

- Topology declares nodes/links/images; startup configs define deterministic initial
  device intent. (2)
- Container naming gives repeatable command targets, while deploy/destroy creates and
  removes runtime state for a clean cycle. (1)
- Save commands, timestamps, expected/actual outputs, and relevant config/version so
  another operator can reproduce the observation. (1)
- Stale containers, namespaces, configs, routes, or captures can make a new test inherit
  an old fix/fault; confirm clean lifecycle and current topology before concluding. (1)

## Remediation

| Weak area | Review |
|---|---|
| ContainerLab lifecycle, two-router OSPF state, timers, routes, and evidence | `labs/two-routers/` |
