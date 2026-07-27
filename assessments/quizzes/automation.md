# Topic Quiz — Network Automation and Source of Truth

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `automation-fundamentals` and `network-automation-netbox`.

## Section 1 — Mechanisms (6 points)

### A1 — Failure layers in an API workflow (3 points)

Classify each result and name the first troubleshooting layer:

1. TCP connection refused;
2. HTTP `401 Unauthorized`; and
3. HTTP 200 with a JSON-RPC `error` object.

(3 pts)

### A2 — Idempotence and closed-loop verification (3 points)

Explain why “the API accepted the configuration” proves neither idempotence nor network
success. Define the read-change-verify behavior a safe script should exhibit on its
first and second runs. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — Green script, missing route

An automation job adds `Loopback7` and originates it in BGP on `leaf1`.

```text
leaf1 API response: success
leaf1 running config: network 192.0.2.77/32
leaf1 local BGP table: 192.0.2.77/32 valid, local
spine1 BGP table: prefix absent
job result: PASS
```

1. Explain why the job's success condition is too weak. (2 pts)
2. Give three remote checks or preconditions that local verification missed. (3 pts)
3. Define a bounded failure behavior for the job rather than an indefinite wait or false
   PASS. (2 pts)
4. State what the second identical run should change. (1 pt)

## Section 3 — Application (10 points)

### C1 — Guard a source-of-truth rollout

NetBox contains a proposed access VLAN and four interface assignments. Design a workflow
from modeled intent to production that includes data validation, rendering, diff review,
deployment scope, operational verification, and recovery. State where an overlapping
prefix or a bad shared template should be stopped. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Which side is authoritative?

During an incident, an engineer manually changes a leaf uplink description and IP
address. The next discovery sync can update NetBox from the device; the next deployment
can instead overwrite the device from NetBox.

Give a decision method for choosing the reconciliation direction, the evidence that must
be preserved, and one safeguard that prevents an automatic sync from silently turning
an emergency change into intended state. (6 pts)

*Key: [`../answer-keys/quizzes/automation-key.md`](../answer-keys/quizzes/automation-key.md).*
