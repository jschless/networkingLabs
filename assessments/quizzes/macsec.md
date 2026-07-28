# Topic Quiz — MACsec Link Security

**Time:** 25 minutes · **Total:** 20 points · **Closed book, no CLI**

**Prerequisites:** `macsec-basics`.

## Section 1 — Mechanisms (4 points)

### A1 — Protect one link (4 points)

Contrast MACsec with IPsec by layer, hop scope, protected frame content, and common
deployment boundary. State the role of MKA and the CAK/CKN relationship. (4 pts)

## Section 2 — Evidence reading (6 points)

### B1 — Control frames repeat, protected traffic never starts

```text
capture eth1: repeated EtherType 0x888e
capture eth1: no EtherType 0x88e5
capture macsec0: no ICMP
r1 CKN: branch-uplink
r2 CKN: branch-uplink-new
plain eth2 ping: success
```

1. Interpret the two EtherTypes and localize the failure. (3 pts)
2. Explain why the plain-link success matters. (1 pt)
3. Give the minimum repair and two verification captures/counters. (2 pts)

## Section 3 — Application (5 points)

### C1 — Place MACsec from the threat model

Choose where MACsec adds value in a campus with exposed building-to-building fiber,
trusted in-rack links, and an Internet WAN. Defend each placement or omission and state
what remains visible on a protected Ethernet link. (5 pts)

## Section 4 — Design and troubleshooting (5 points)

### D1 — Rotate keys safely

Design a CAK rotation and replay-protection verification that avoids an avoidable outage.
Include overlap/coordination, MKA state, live-traffic observation, replay counters, and a
rollback condition. (5 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/macsec-key.md`](../answer-keys/quizzes/macsec-key.md).*
