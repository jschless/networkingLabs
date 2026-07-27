# Answer Key — Enterprise QoS Topic Quiz

**Total:** 20 points

## A1 — Classification bits (2 points)

1. DSCP 46 shifted left two bits is binary `10111000`, or ToS `0xb8`. (1)
2. Mask `0xfc` compares the upper six DSCP bits while ignoring the lower two ECN bits,
   so packets remain in the same behavior aggregate as ECN changes. (1)

## A2 — Controlling excess traffic (2 points)

- A shaper buffers and delays excess traffic to smooth it to the configured rate; it is
  commonly applied on egress toward the actual bottleneck. (1)
- A policer normally forwards conforming traffic and drops or remarks excess immediately;
  it is often applied at ingress or at an administrative rate boundary. (1)

## B1 — Read the queues, not just the throughput (6 points)

1. `overlimits` records attempts to exceed the class's guaranteed token rate; the class
   may borrow available capacity up to its ceiling. With zero drops and an offered rate
   below the guarantee, the counter alone does not demonstrate voice loss. (2)
2. `early 287` shows active queue management dropping selected video packets before the
   queue is completely full. Early drop signals congestion and avoids a synchronized,
   full-queue tail-drop event. (2)
3. The link is congested: video and especially data have drops. The voice class remains
   protected, video receives its assured treatment with AQM, and best effort absorbs the
   largest loss under sustained competition. Counters should be interpreted with the
   offered rates and end-user loss/jitter measurements. (2)

**Misconception:** An `overlimits` counter is not interchangeable with a drop counter.

## C1 — Build a branch policy (5 points)

One acceptable design:

- Guarantee voice 1.2 Mbps, video 2 Mbps, and data 1 Mbps beneath a 5-Mbps parent. The
  4.2-Mbps sum leaves capacity for overhead or policy headroom; each class may borrow up
  to the parent ceiling when capacity is idle. Equivalent non-overbooked allocations
  receive full credit. (2)
- Give voice a low-latency priority treatment with a deliberate cap, video an assured
  class with an AQM such as WRED, and data a fair queue such as SFQ/FQ-CoDel at lowest
  priority. (2)
- Send unclassified traffic to the best-effort/data class rather than a priority queue.
  (1)

Do not award full credit to an uncapped strict-priority class that could starve every
other class.

## D1 — Correct markings, wrong queue (5 points)

- Two likely faults, 1 point each: the qdisc/filter is attached to the wrong interface or
  direction; the filter is bound to the wrong qdisc parent; the classifier uses the wrong
  DS-field value/mask, IP family, or priority; or the filter directs traffic to a
  nonexistent/wrong class. (2)
- Evidence sequence, 3 points: capture before or at egress to prove `0xb8`; inspect the
  qdisc, class hierarchy, and filter attachment on the actual bottleneck interface; run
  one controlled EF stream while watching both filter hits and per-class counters.
  Marking is exonerated when the packet bits are correct, while lack of filter hits or
  hits on the default path localizes attachment/classification. (3)

## Remediation

| Weak area | Review |
|---|---|
| DSCP encoding, HTB hierarchy, AQM, policing, and queue counters | `labs/qos-enterprise/` |
