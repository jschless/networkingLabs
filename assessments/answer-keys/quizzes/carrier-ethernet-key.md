# Answer Key — Carrier Ethernet Handoffs Topic Quiz

**Total:** 30 points

## A1 — QinQ service boundaries (3 points)

- The CE/UNI customer side carries the inner C-tag VLAN 220. (1)
- The ingress NID pushes outer 802.1ad S-tag 3220, so the provider-facing NID and core
  carry outer 3220 plus inner 220. (1)
- The far NID matches/pops S-tag 3220 and presents customer VLAN 220 at the far UNI. (1)

## A2 — MTU and class of service (3 points)

- Provider links must accommodate the customer's committed IP packet plus Ethernet
  framing and the additional provider VLAN tag; otherwise a nominally accepted customer
  frame becomes oversized in the core. (2)
- Generate marked customer traffic and inspect the actual outer PCP in a provider-side
  capture at ingress and egress, comparing it with the service order. (1)

## B1 — One healthy service masks the wrong cross-connect (8 points)

1. Both ingress/core captures correctly carry Silver as 3120/120. `nid-b` incorrectly
   pops outer 3100 into VLAN 120, so it never matches Silver 3120. Gold uses 3100 and can
   remain healthy on its separate valid mapping. (3)
2. Change only the far NID Silver reverse flow to match S-VLAN 3120, pop it, and deliver
   customer VLAN 120. (2)
3. Prove Silver bidirectional reachability, captures showing 3120/120 in the provider and
   inner 120 at each UNI, and continued Gold plus cross-service isolation. Equivalent
   inclusion of MTU/PCP acceptance may replace one check. (3)

## C1 — Build an acceptance plan (10 points)

- Verify the order/circuit identifiers and capture inner-to-outer VLAN mapping at both
  NIDs for every service. (2)
- Test bidirectional reachability and throughput with source/interface binding. (1)
- Prove the committed 1600-byte IP packet passes with DF and a one-byte-larger packet
  fails according to the contract. (2)
- Capture outer PCP for preserve/rewrite classes in both directions. (1)
- Run negative cross-service and provider-management/OAM reachability tests. (1)
- Record timestamps, direction, frame size, loss/latency/throughput, commands, captures,
  and measured outcomes in the signed-style report. (2)
- Label fixture/evidence-only CFM, optical, or physical deductions and never present them
  as live counters. (1)

## D1 — Escalate intermittent Silver loss (6 points)

Include:

- circuit/service identifiers, customer VLAN 120/S-VLAN 3120, exact time window/time
  zone, direction, and affected frame sizes/traffic class; (2)
- CE-side and NID/core captures showing frames enter correctly tagged and loss begins at
  or beyond the demarc, plus flow/counter and acceptance results; (2)
- measured loss/PCP/MTU behavior, successful Gold comparison, and reproduction frequency;
  and (1)
- an explicit statement that CFM/optical data are fixture or unavailable, with a request
  for provider investigation rather than an invented optic/policing diagnosis. (1)

## Remediation

| Weak area | Review |
|---|---|
| QinQ, MTU/PCP acceptance, cross-connect diagnosis, and demarc escalation | `labs/carrier-ethernet-handoff/` |
