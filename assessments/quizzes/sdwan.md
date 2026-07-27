# Topic Quiz — SD-WAN and Orchestrated Overlays

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `sdwan-concepts` and `orchestrated-wan-overlay`.

## Section 1 — Mechanisms (6 points)

### A1 — Separate the planes (3 points)

Distinguish transport underlay reachability, encrypted overlay/tunnel state, centralized
control/policy state, and application-path health. Explain why a successful ISP ping
proves only one of them. (3 pts)

### A2 — Application-aware path selection (3 points)

Explain the sequence from traffic classification through policy-table lookup, SLA
measurement, failover threshold, and failback hold-down. State why reachability-only
probes miss a brownout. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — Green transports, withdrawn private service

```text
branch7 underlay probes: private=UP internet=UP
branch7 certificate: serial 44A2, revoked
controller: branch7 control=down, applied_version=none
branch7 wg show: no recent handshake
branch7 private route: absent
branch7 SaaS breakout: HTTP 200
```

1. Localize the failure across the four planes. (3 pts)
2. Explain why SaaS and underlay success do not contradict the private-service outage.
   (2 pts)
3. Give a minimal identity repair and three verification boundaries. (3 pts)

## Section 3 — Application (10 points)

### C1 — Roll out policy without confusing intent and state

A controller publishes version 12 to 80 branches. It changes CORP route policy and must
not leak GUEST into the private overlay. Design a staged publish, acknowledgement,
service verification, failure stop, and rollback workflow. Explain why
`desired_version=12` is insufficient evidence. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Tune a brownout response

Voice requires less than 80 ms latency and less than 2% loss. A path occasionally has
one bad sample but sometimes degrades for minutes without going down. Propose the
measurement window, failure/recovery thresholds, and hold-down behavior. Give evidence
that proves bounded failover without route oscillation or asymmetric policy. (6 pts)

*Key: [`../answer-keys/quizzes/sdwan-key.md`](../answer-keys/quizzes/sdwan-key.md).*
