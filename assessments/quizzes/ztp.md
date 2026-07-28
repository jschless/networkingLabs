# Topic Quiz — Zero-Touch Provisioning

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `ztp-basics`.

## Section 1 — Mechanisms (6 points)

### A1 — Enter and complete ZTP (3 points)

Explain the EOS files that gate ZTP at boot, the role of DHCP option 67, and the event
that marks successful completion rather than another retry. (3 pts)

### A2 — Bootstrap trust (3 points)

Explain the risk of trusting the first DHCP response and an unsigned HTTP configuration.
Give three controls that improve device identity, server authenticity, or artifact
integrity during day zero. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — A healthy DHCP loop that never provisions

```text
DHCP log: DISCOVER -> OFFER -> REQUEST -> ACK
option 67: http://172.30.30.50:8000/branch-17.cfg
HTTP log: GET /branch-17.cfg 404
switch log: ZTP fetch failed; retry scheduled
startup-config: absent
zerotouch-config: absent
```

1. Localize the failure and explain why DHCP success is not ZTP success. (3 pts)
2. Give the minimum live repair. (2 pts)
3. Give three observations proving the next retry completed and the production config
   actually works. (3 pts)

## Section 3 — Application (10 points)

### C1 — Provision 400 unique switches safely

Design a fleet ZTP service that selects per-device intent, limits rogue provisioning,
protects secrets, validates generated configuration, records an audit trail, and hands
ongoing ownership to the normal automation/source-of-truth system. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Config applied, branch still unreachable

The switch has the expected hostname and banner, but users cannot reach the server
network. Describe how to distinguish incomplete delivered configuration from a fetch or
ZTP-state problem, give the minimum correction workflow, and define rollback or rescue
access for a dark branch. (6 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/ztp-key.md`](../answer-keys/quizzes/ztp-key.md).*
