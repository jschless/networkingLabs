# Topic Quiz — Enterprise Campus Design

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** the collapsed-core, three-tier campus, routed-access, and WAN-edge
reference labs and their capstones.

## Section 1 — Mechanisms (6 points)

### A1 — Where the boundary lives (3 points)

Compare collapsed-core, three-tier, and routed-access campuses by locating the Layer-2
boundary, default gateway, and principal failure domain. (3 pts)

### A2 — Aligning forwarding decisions (3 points)

Explain why the STP root and VRRP master should be the same distribution switch for a
VLAN, and trace the inefficient path when they are not. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — Redundancy exists, but not for this access switch

dist1 and dist2 are healthy. acc1 has one trunk to dist1; its documented second uplink to
dist2 was never cabled. dist1 fails. VRRP moves to dist2 and the core still has all routes,
but every acc1 user is offline.

1. Localize the failed layer and explain why VRRP/OSPF health is irrelevant to acc1.
   (3 pts)
2. Give the minimum topology repair and the STP state expected in steady state. (2 pts)
3. Give three checks proving gateway, Layer-2, and end-to-end recovery. (3 pts)

## Section 3 — Application (10 points)

### C1 — Select a campus model

Choose and defend a design for each site:

1. A small campus needs simple operations and accepts one redundant pair as the combined
   core/distribution layer. (3 pts)
2. A large campus needs a policy-rich distribution boundary and a simple, scalable core.
   (3 pts)
3. A new campus values per-link failure isolation, ECMP, and fast convergence over
   cross-switch VLAN mobility. (4 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — The default must follow reality

A dual-homed WAN edge advertises `default-information originate always` into the campus.
Both ISP sessions fail but the OSPF default remains. Explain the failure, propose a
conditional design, and give control-plane plus user-path verification. (6 pts)

*Key: [`../answer-keys/quizzes/enterprise-design-key.md`](../answer-keys/quizzes/enterprise-design-key.md).*
