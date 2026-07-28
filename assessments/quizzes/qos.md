# Topic Quiz — Enterprise QoS

**Time:** 25 minutes · **Total:** 20 points · **Closed book, no CLI**

**Prerequisites:** `qos-enterprise`.

This quiz tests classification, congestion management, and verification at a changed
branch-office bottleneck.

## Section 1 — Mechanisms (4 points)

### A1 — Classification bits (2 points)

An EF packet has DSCP 46 and may also carry ECN bits.

1. Give the hexadecimal ToS byte when the ECN bits are zero. (1 pt)
2. Explain why a classifier can match the DS field with mask `0xfc` rather than
   matching all eight bits. (1 pt)

### A2 — Controlling excess traffic (2 points)

Contrast shaping and policing by stating what each normally does to traffic above its
rate and where each is commonly placed relative to a WAN bottleneck. (2 pts)

## Section 2 — Evidence reading (6 points)

### B1 — Read the queues, not just the throughput

A 2-Mbps egress policy reports:

```text
class 1:10 voice  rate 800Kbit  Sent 61MB  dropped 0     overlimits 1821
class 1:20 video  rate 600Kbit  Sent 44MB  dropped 312   early 287
class 1:30 data   rate 600Kbit  Sent 39MB  dropped 4290
```

Voice is offered at 500 kbps, while video and data both attempt to consume all remaining
bandwidth.

1. Explain why rising voice `overlimits` does not by itself prove user-impacting loss.
   (2 pts)
2. Interpret the video `early` counter and name the queue-management purpose it serves.
   (2 pts)
3. Explain what the counters say about congestion and class protection overall. (2 pts)

## Section 3 — Application (5 points)

### C1 — Build a branch policy

A 5-Mbps WAN must carry 1.2 Mbps of voice, at least 2 Mbps of business video, and
best-effort backups that can fill the link overnight. Propose:

1. guaranteed rates and ceilings that do not overbook the parent guarantee; (2 pts)
2. a scheduling/queue treatment for each class; and (2 pts)
3. the default behavior for unclassified traffic. (1 pt)

Exact numbers may vary, but the policy must protect real-time traffic and allow unused
capacity to be borrowed safely.

## Section 4 — Design and troubleshooting (5 points)

### D1 — Correct markings, wrong queue

A capture on the WAN interface shows voice leaving with ToS `0xb8`, but every class
counter remains at zero except the default class. Give two likely policy-attachment or
classification faults and an evidence sequence that distinguishes them from a marking
problem. (5 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/qos-key.md`](../answer-keys/quizzes/qos-key.md).*
