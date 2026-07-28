# Topic Quiz — SIEM and Incident Response

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `soc-elk-ingest`, `soc-kibana-hvt-dashboard`,
`soc-ir-case-management`, and `soc-adversary-simulation`.

## Section 1 — Mechanisms (6 points)

### A1 — Normalize without erasing meaning (3 points)

Explain how Zeek `id.orig_h`, Suricata `src_ip`, and a YARA file path can be mapped into
common analyst fields while retaining source-specific raw fields and provenance. (3 pts)

### A2 — Dashboards and cases (3 points)

Contrast a monitoring dashboard with an incident case. Give three ways aggregation,
time-window choice, or metric selection can make a dashboard look healthy during a real
attack. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — Reconstruct the timeline

```text
12:00:04 Zeek: external host opens TCP/22 to bastion
12:00:09 Suricata: repeated-login alert for the same tuple
12:03:40 YARA: extracted file /extract_files/update.bin matches Suspicious_Update
12:05:10 case note: "bastion isolated at 12:01"
12:07:00 packet record: bastion still sends traffic to an internal host
```

1. Identify the timeline inconsistency and two possible explanations. (3 pts)
2. Give the evidence needed to establish actual containment time. (3 pts)
3. State how the case should record uncertainty without rewriting history. (2 pts)

## Section 3 — Application (10 points)

### C1 — Work the incident end to end

Design the workflow from alert triage through scoped containment, evidence preservation,
observables, timeline, eradication/recovery criteria, and post-incident detection
improvement. Include chain of custody and independent reproducibility. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Turn adversary simulation into a finding

A contained simulation completes four ATT&CK-style steps, but only two generate alerts.
Describe how to distinguish expected non-alerting telemetry from a true detection gap,
record coverage, prioritize remediation, and retest without attacking live targets.
(6 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/siem-ir-key.md`](../answer-keys/quizzes/siem-ir-key.md).*
