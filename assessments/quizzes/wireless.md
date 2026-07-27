# Topic Quiz — Enterprise Wireless Operations

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `enterprise-wireless-architecture` and
`wireless-auth-control-operations`.

## Section 1 — Mechanisms (6 points)

### A1 — Where client traffic enters the wired network (3 points)

Compare controller-tunneled and locally bridged WLAN designs. State where client traffic
is decapsulated, where its VLAN or segment must exist, and one roaming or failure-domain
tradeoff of each. (3 pts)

### A2 — Identity is not the final policy (3 points)

Trace an EAP-TLS client through supplicant server validation, RADIUS authentication,
authorization attributes, authenticator VLAN projection, and service policy. State why
`Access-Accept` alone does not prove correct access. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — Guest works while corporate cannot join

```text
corp client:
TLS: certificate subject did not match radius.branch.example
CTRL-EVENT-EAP-FAILURE

RADIUS:
Access-Request user=alice
TLS negotiation started
no Access-Accept

authenticator:
corp port unauthorized
guest fixture VLAN 120 forwarding
```

1. Localize the corporate failure and explain why guest success is relevant but not
   contradictory. (3 pts)
2. State the unsafe “fix” that must be rejected. (1 pt)
3. Give the minimum repair and four pieces of evidence that prove identity,
   authorization, VLAN, and service recovery. (4 pts)

## Section 3 — Application (10 points)

### C1 — Design three wireless policy products

A branch needs corporate, guest, and remediation/quarantine access. Design the wired and
identity path from AP uplink through controller/RADIUS to the three service zones.
Include management separation, VLAN/segment mapping, role authorization, firewall
policy, and negative verification. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Do not turn a wired fixture into an RF claim

A client reports intermittent roaming failures. Authentication logs show successful
EAP-TLS and correct VLAN assignment after each attempt, while a supplied radio evidence
record shows high channel utilization at one AP. Give a disciplined evidence plan that
distinguishes RF capacity, sticky-client/roaming behavior, controller state, and wired
policy. State what the containerized policy labs can and cannot prove. (6 pts)

*Key: [`../answer-keys/quizzes/wireless-key.md`](../answer-keys/quizzes/wireless-key.md).*
