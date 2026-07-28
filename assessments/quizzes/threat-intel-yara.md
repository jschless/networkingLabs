# Topic Quiz — Threat Intelligence and YARA

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `soc-threat-intel-misp` and `soc-yara-file-pipeline`.

## Section 1 — Mechanisms (6 points)

### A1 — Indicator lifecycle (3 points)

Explain why IP, domain, and file-hash indicators have different useful lifetimes and
false-positive risks. State what confidence, provenance, and expiry data should travel
with an operationalized IOC. (3 pts)

### A2 — Content rules and evasion (3 points)

Explain how a naive single-string YARA rule can be evaded and how multiple strings,
hex/wildcard patterns, file structure/imports, and conditions improve resilience without
eliminating false positives. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — Two matches, different confidence

```text
MISP-style event: IP 203.0.113.90, confidence 35, first_seen 180 days ago,
                  source="unverified community feed"
Suricata exported rule: alert on any traffic to 203.0.113.90

YARA hit: rule Invoice_Dropper on /extract_files/invoice.txt
matched: "$marker = SOC_LAB_TEST_FILE"
file hash: not present in threat-intel event
```

1. Assess the IP alert's operational risk. (2 pts)
2. Explain what the YARA hit proves and does not prove. (2 pts)
3. Give four enrichment or validation steps before declaring an incident. (4 pts)

## Section 3 — Application (10 points)

### C1 — Design an intel-to-detection pipeline

Design ingestion, scoring, expiry, review, rule generation, testing, deployment,
alert-correlation, and feedback for network IOCs and extracted-file YARA rules. Include
rollback and provenance. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — A rule floods the SOC

A newly deployed IOC/YARA rule produces thousands of alerts on approved software and
shared infrastructure. Give a tuning method that reduces noise without deleting the
evidence trail or globally suppressing future malicious use. (6 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/threat-intel-yara-key.md`](../answer-keys/quizzes/threat-intel-yara-key.md).*
