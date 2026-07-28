# Topic Quiz — Routed Network Foundations

**Time:** 25 minutes · **Total:** 20 points · **Closed book, no CLI**

**Prerequisites:** `two-routers`.

## Section 1 — Mechanisms (4 points)

### A1 — From link to learned route (4 points)

Distinguish physical/link state, IP adjacency, OSPF neighbor state, synchronized LSDB,
RIB installation, and successful bidirectional forwarding. (4 pts)

## Section 2 — Evidence reading (6 points)

### B1 — The far side shut its interface

The container veth remains present on `r1`, but `r2` administratively shuts its routed
interface. `r1` initially still shows the neighbor.

Explain the expected neighbor timing, the controlling OSPF timers, the route-table
change, and evidence that distinguishes this from immediate local carrier loss. (6 pts)

## Section 3 — Application (5 points)

### C1 — Verify a two-router deployment

Give a minimal ordered verification from topology/container state through interfaces,
addressing, OSPF, routes, and a sourced ping. State why each layer is not implied by the
previous one. (5 pts)

## Section 4 — Design and troubleshooting (5 points)

### D1 — Make the lab result reproducible

Explain the roles of topology definition, startup configuration, container naming,
deploy/destroy lifecycle, and saved evidence. Describe how stale runtime state can create
a false troubleshooting conclusion. (5 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/routing-foundations-key.md`](../answer-keys/quizzes/routing-foundations-key.md).*
