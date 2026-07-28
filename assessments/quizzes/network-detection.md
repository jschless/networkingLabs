# Topic Quiz — Network Detection and PCAP Investigation

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `soc-dmz-foundation`, `soc-zeek-analysis`,
`soc-suricata-ids`, and `soc-arkime-pcap`.

## Section 1 — Mechanisms (6 points)

### A1 — Three evidence products (3 points)

Contrast Zeek protocol metadata, Suricata alerts, and Arkime/full-packet session evidence.
Give one question each answers especially well and one limitation shared by none of the
others. (3 pts)

### A2 — Detection is not verdict (3 points)

Explain why a signature match must be correlated with session behavior, asset context,
and packets before containment. State when thresholding or suppression is appropriate
and what must remain observable. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — Correlate one SSH alert

```text
Suricata: 12:04:10 src=198.51.100.77 dst=10.20.20.10 dport=22
           signature="Repeated SSH Login Attempts" severity=2
Zeek conn: 12:04:01-12:04:18, same tuple, 34 short TCP sessions, orig_bytes=2040
Arkime: session group references dmz-1204.pcap frames 880-1412
asset inventory: 10.20.20.10 is an Internet-facing bastion
```

1. State the strongest supported hypothesis and one alternative. (3 pts)
2. Give the packet/session evidence that would raise or lower confidence. (3 pts)
3. Give a proportionate immediate action that preserves evidence. (2 pts)

## Section 3 — Application (10 points)

### C1 — Build a triage workflow

Design a repeatable alert-to-PCAP workflow that preserves timestamps and identifiers,
correlates Zeek/Suricata/Arkime records, incorporates asset criticality, distinguishes
true and false positives, and records a defensible containment decision. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Retention under a storage limit

Design metadata and full-packet retention for a busy DMZ under a fixed storage budget.
Explain tiering, selective capture, privacy/access controls, and which investigations
become impossible after packet expiry. (6 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/network-detection-key.md`](../answer-keys/quizzes/network-detection-key.md).*
