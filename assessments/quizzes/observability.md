# Topic Quiz — Network Observability and Assurance

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `network-assurance`, `suzieq-network-observability`,
`telemetry-monitoring-hybrid`, and `packet-analysis-basics`.

## Section 1 — Mechanisms (6 points)

### A1 — Match evidence to the question (3 points)

For each question, choose the most direct primary evidence source and justify it:

1. Which conversations consumed a WAN link during the last five minutes?
2. What exact packets and flags crossed one switch port during a failed transaction?
3. When did an OSPF adjacency change state, according to the router?

Choose among flow records, a SPAN packet capture, centralized syslog, and periodic SNMP
interface polling. (3 pts)

### A2 — Polling, streaming, and active tests (3 points)

Contrast periodic polling, streaming telemetry, and an active service probe by stating
one failure or behavior each can reveal especially well. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — A healthy snapshot from yesterday

SuzieQ last polled at 10:00. At 10:01, `r2:Ethernet2` failed. At 10:03:

```text
sq ospf show       -> r2-r3 state Full
sq interface show  -> r2 Ethernet2 state up
central syslog     -> 10:01:04 OSPF neighbor Down on Ethernet2
active probe       -> r1 loopback cannot reach r3 loopback
```

1. Reconcile the apparently contradictory evidence. (3 pts)
2. State the next two collection or query actions that would update and then validate
   the fleet view. (2 pts)
3. Identify one timestamp or freshness control an automated assertion gate must enforce.
   (1 pt)
4. Explain why a successful management-plane poll after recovery still does not replace
   an end-to-end probe. (2 pts)

## Section 3 — Application (10 points)

### C1 — Design an assurance gate

A maintenance workflow changes OSPF costs on twenty routers. Design a before/after gate
that uses:

- a fleet-state assertion;
- a path or route check;
- a time-series or interface-counter check; and
- an active user-path test.

State what baseline is captured, what causes rollout to stop, and how you prevent stale
or known-benign assertion results from producing a false decision. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Reachability is green, checkout is red

ICMP to a retail site's service VIP succeeds. Device inventory is complete and every
interface is operational. Customers still cannot complete an HTTPS checkout. Build a
four-step evidence plan using at least three assurance mechanisms, and explain why
device-up and interface-up signals are insufficient. (6 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/observability-key.md`](../answer-keys/quizzes/observability-key.md).*
