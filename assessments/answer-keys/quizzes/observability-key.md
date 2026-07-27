# Answer Key — Network Observability and Assurance Topic Quiz

**Total:** 30 points

## A1 — Match evidence to the question (3 points)

1. Flow records summarize conversations, byte counts, and timing over the interval. (1)
2. A SPAN-fed packet capture preserves the frames, headers, flags, and sequence needed
   for transaction-level analysis. (1)
3. Centralized syslog records the router's timestamped adjacency transition and reason
   at the time it occurred. (1)

SNMP counters can corroborate utilization or errors, but they are not the most direct
source for any of these three exact questions.

## A2 — Polling, streaming, and active tests (3 points)

- Periodic polling is well suited to inventory, reachability state, and regularly sampled
  counters, but can miss short events between polls. (1)
- Streaming telemetry supplies higher-frequency state/counter changes and time-series
  visibility without waiting for the next poll. (1)
- An active probe tests a synthetic user transaction or path, exposing failures where
  devices and interfaces remain up but DNS, transport, TLS, or application behavior is
  wrong. (1)

## B1 — A healthy snapshot from yesterday (8 points)

1. SuzieQ is answering from the 10:00 snapshot; it does not query routers live for each
   command. Syslog and the active probe reflect the later failure, so the observations
   describe different times rather than contradictory current state. (3)
2. Re-run or wait for a successful poll, then rerun the interface/OSPF assertions and a
   path or route query against the new snapshot. (2)
3. Require a collection timestamp, maximum data age, successful poll status, or all
   three before accepting an assertion result. (1)
4. Management reachability proves collection access, not the forwarding path or service
   transaction. The active source/destination path must still be tested. (2)

**Misconception:** Repeating a query against the same Parquet snapshot does not refresh
the data.

## C1 — Design an assurance gate (10 points)

Award credit for these elements:

- Capture a timestamped pre-change baseline of expected adjacencies, routes/paths,
  relevant interface counters, and the active test result. (2)
- After each limited rollout batch, collect fresh fleet state and require the expected
  OSPF adjacencies to remain healthy. (2)
- Confirm the intended path or route changed as designed and unrelated paths did not
  disappear. (2)
- Compare counter rates rather than only cumulative values, looking for new errors,
  drops, or abnormal utilization, and run a representative bidirectional user-path
  probe. (2)
- Stop and return nonzero on unexpected deltas; enforce freshness and collection
  completeness, and explicitly classify/version known-benign assertion exceptions
  instead of ignoring all failures. (2)

Equivalent gates receive full credit when they test both intended change and unintended
impact with current data.

## D1 — Reachability is green, checkout is red (6 points)

One complete four-step plan:

1. Run a client-side DNS plus HTTPS transaction, preserving status, TLS failure, latency,
   and a request ID. (1)
2. Correlate the request timestamp/ID with centralized device and service logs to locate
   the failing boundary. (1)
3. Inspect flow records and interface/error time series to confirm the path taken and
   identify loss, resets, or saturation. (1)
4. Take a targeted SPAN or endpoint capture to distinguish DNS, TCP, TLS, and HTTP
   failure and verify return traffic. (1)

Award the remaining 2 points for explaining that ICMP and operational interfaces test
only limited network reachability; they do not validate name resolution, the required
port, TLS/SNI/certificate behavior, stateful return flow, or the checkout application.

## Remediation

| Weak area | Review |
|---|---|
| SNMP, syslog, SPAN, and flow records | `labs/network-assurance/` |
| Fleet snapshots, path queries, and assertions | `labs/suzieq-network-observability/` |
| Polling versus streaming telemetry and NMS state | `labs/telemetry-monitoring-hybrid/` |
| Packet-level evidence and protocol boundaries | `labs/packet-analysis-basics/` |
