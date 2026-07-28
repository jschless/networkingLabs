# Topic Quiz — Troubleshooting Methodology

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** the `troubleshooting-range`, `troubleshooting-range-campus`, and
`troubleshooting-range-advanced` engineer workflows.

## Section 1 — Mechanisms (6 points)

### A1 — A defensible repair (3 points)

Define symptom scope, hypothesis, discriminating evidence, minimum correction, and
user-plus-infrastructure verification. Explain why a correct guess without method is
operationally weak. (3 pts)

### A2 — Red flags (3 points)

Explain why shotgun changes, symptom-masking workarounds, and unverified repairs receive
assessment caps even when service appears to return. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — “The portal is down”

```text
client DNS: portal.range.test -> 10.250.40.10
client TCP SYN to 10.250.40.10:8080 leaves
services host capture: SYN arrives; no SYN/ACK leaves
services route back to client subnet: present
ss -lnt: service listening on 127.0.0.1:8080 only
```

1. State the scope and root cause. (3 pts)
2. Give the minimum correction. (2 pts)
3. Give three verification results that close the ticket. (3 pts)

## Section 3 — Application (10 points)

### C1 — Work a multi-layer incident

Users in one VLAN cannot reach a remote service, while other VLANs work. Write an ordered
method covering endpoint, access VLAN, gateway, routing/control plane, forward/return
path, service listener, and policy. Include stop conditions and evidence preservation.
(10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Prove a PMTUD diagnosis

Small HTTPS responses work but large downloads stall across an edge path. Give the
hypothesis, packet/control evidence, minimal policy or MTU repair, negative alternatives
to eliminate, and client-side plus infrastructure verification. (6 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/troubleshooting-method-key.md`](../answer-keys/quizzes/troubleshooting-method-key.md).*
