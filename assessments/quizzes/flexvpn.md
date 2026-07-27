# Topic Quiz — FlexVPN and Route-Based IPsec

**Time:** 25 minutes · **Total:** 20 points · **Closed book, no CLI**

**Prerequisites:** `flexvpn-basics`.

## Section 1 — Mechanisms (4 points)

### A1 — Bind a route to an SA (4 points)

Explain how an IKEv2/IPsec SA, VTI, XFRM mark, route, and `disable_policy` setting work
together in route-based IPsec. (4 pts)

## Section 2 — Evidence reading (6 points)

### B1 — Established is not forwarding

```text
IKE_SA spoke4[7] ESTABLISHED
CHILD_SA installed mark 4
vti0: key 3, state UP
route 192.168.40.0/24 via 10.10.4.1 dev vti0
ping hub VTI: fail
```

Identify the fault, explain why IKE remains established, and give the repair plus
wire-side and VTI-side verification. (6 pts)

## Section 3 — Application (5 points)

### C1 — Add dynamic routing

Replace spoke static routes with an IGP over point-to-point VTIs. State adjacency scope,
advertised prefixes, failure behavior, route filtering, and verification. (5 pts)

## Section 4 — Design and troubleshooting (5 points)

### D1 — Fifty spokes and heavy east-west traffic

Explain the state, CPU, latency, and configuration implications of per-spoke VTIs and
hub hairpinning. Compare when FlexVPN's model remains defensible and when a dynamic
shortcut or different architecture is preferable. (5 pts)

*Key: [`../answer-keys/quizzes/flexvpn-key.md`](../answer-keys/quizzes/flexvpn-key.md).*
