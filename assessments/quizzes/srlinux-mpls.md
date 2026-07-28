# Topic Quiz — SR Linux SR-MPLS Operations

**Time:** 25 minutes · **Total:** 20 points · **Closed book, no CLI**

**Prerequisites:** `mpls-sr-srlinux`.

## Section 1 — Mechanisms (4 points)

### A1 — Map the service stack (4 points)

Map SR Linux network instances, `bgp-vpn`, VPNv4, SRGB/node SIDs, and the MPLS forwarding
table to the control and forwarding jobs of an L3VPN. (4 pts)

## Section 2 — Evidence reading (6 points)

### B1 — VPN route exists globally, not in the customer table

```text
default BGP l3vpn-ipv4-unicast: remote route present with RT 65000:100
CUST-A bgp-vpn import-rt: 65000:200
CUST-A route-table: remote CE prefix absent
SR transport label to remote PE: installed
```

Identify the failed layer, give the minimum repair, and state three checks proving
service recovery without changing the SR underlay. (6 pts)

## Section 3 — Application (5 points)

### C1 — Verify one customer packet

Give an evidence sequence across CE route, PE VRF, VPNv4 route, SR transport label, LFIB,
remote VRF, and end-to-end return traffic. (5 pts)

## Section 4 — Design and troubleshooting (5 points)

### D1 — Operate a YANG-based NOS safely

Explain candidate configuration, validation/diff, explicit BGP policy, commit, operational
verification, and rollback. Contrast one risk with a default-accept CLI workflow. (5 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/srlinux-mpls-key.md`](../answer-keys/quizzes/srlinux-mpls-key.md).*
