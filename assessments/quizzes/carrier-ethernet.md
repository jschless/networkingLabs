# Topic Quiz — Carrier Ethernet Handoffs

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `carrier-ethernet-handoff`.

## Section 1 — Mechanisms (6 points)

### A1 — QinQ service boundaries (3 points)

Trace a customer VLAN 220 frame across a UNI mapped to provider S-VLAN 3220. State which
tags appear at the CE, provider-facing NID, core, and far-end UNI. (3 pts)

### A2 — MTU and class of service (3 points)

Explain why a committed 1600-byte IP MTU requires a larger provider Ethernet MTU and how
an operator proves outer-PCP preservation or rewrite without trusting configuration.
(3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — One healthy service masks the wrong cross-connect

The order says Gold `110 -> 3100` and Silver `120 -> 3120`.

```text
Gold: bidirectional pass
Silver: fail
nid-a core capture for VLAN 120: outer 3120, inner 120
nid-b core capture for VLAN 120: outer 3120, inner 120
nid-b UNI flow: match outer 3100 -> pop -> customer VLAN 120
```

1. Localize the defect and explain why Gold remains healthy. (3 pts)
2. Give the minimum repair. (2 pts)
3. Give three acceptance checks that prove the service order after repair. (3 pts)

## Section 3 — Application (10 points)

### C1 — Build an acceptance plan

Create a carrier handoff acceptance plan covering VLAN/QinQ mapping, both directions,
committed MTU and one-byte-over behavior, throughput, PCP treatment, cross-service
isolation, provider-management isolation, and evidence provenance. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Escalate intermittent Silver loss

Write the evidence content—not prose boilerplate—for a provider escalation that
localizes an intermittent one-way Silver fault at or beyond the NID without claiming
unsupported optical or live CFM results. (6 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/carrier-ethernet-key.md`](../answer-keys/quizzes/carrier-ethernet-key.md).*
