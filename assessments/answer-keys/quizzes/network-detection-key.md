# Answer Key — Network Detection and PCAP Investigation Topic Quiz

**Total:** 30 points

## A1 — Three evidence products (3 points)

- Zeek efficiently answers protocol/session behavior questions from structured metadata,
  but generally cannot reproduce packet payload/bytes that were not logged. (1)
- Suricata answers which signature/protocol anomaly matched and with what event context,
  but a match is not a root-cause or maliciousness verdict. (1)
- Arkime/full packet answers exact packet, flag, payload, and sequence questions and
  supports session pivot/export, but is storage-intensive and still needs context. (1)

## A2 — Detection is not verdict (3 points)

- Correlation determines whether the matched behavior occurred, whether the target is
  vulnerable/expected, and whether packets show success or merely an attempt. (2)
- Threshold/suppress repetitive known-benign instances only after validating scope;
  retain counts, source diversity, raw events, and an exception audit so material changes
  remain visible. (1)

## B1 — Correlate one SSH alert (8 points)

1. The strongest hypothesis is automated SSH password guessing or scanning against the
   bastion: 34 short connections align with the repeated-login alert. Alternatives
   include an authorized scanner, broken automation, or a legitimate client retry loop.
   (3)
2. Inspect TCP completion, SSH banners/key exchange, connection duration, server replies,
   authentication logs, timing pattern, other targets, and any successful/post-login
   session. Award up to 3 points for relevant confidence-changing evidence. (3)
3. Preserve/export the alert, correlated logs, and referenced PCAP first; then rate-limit
   or block the source at the narrowest safe boundary while checking for a successful
   login/compromise before broader containment. (2)

## C1 — Build a triage workflow (10 points)

- Preserve original alert/event and use timestamp, five-tuple, sensor, and stable
  session/request identifiers as pivots. (2)
- Query Zeek behavior and Suricata signature context, then locate the exact Arkime
  session/PCAP without altering originals. (2)
- Add asset owner, exposure, criticality, vulnerability, maintenance/scanner allowlists,
  and authentication/application logs. (2)
- Record hypothesis, alternatives, evidence for/against, confidence, true/false-positive
  classification, and scoped containment decision. (2)
- Hash/export retained evidence, use synchronized time/provenance, and capture analyst
  actions so a second analyst can reproduce the result. (2)

## D1 — Retention under a storage limit (6 points)

- Retain searchable flow/protocol metadata longer and full packets for a shorter hot
  window; tier older/high-value captures to compressed or lower-cost storage. (2)
- Prioritize high-value assets, alerts, unusual protocols, and incident holds while using
  documented sampling/truncation for lower-risk traffic. (1)
- Apply encryption, role-based access, audit, minimization, and legal/privacy retention
  controls because packets may contain sensitive content. (1)
- Track packet availability in the case. After expiry, exact payload, sequence-level
  reconstruction, file extraction, and proof of what crossed the wire may be impossible
  even if metadata survives. (2)

## Remediation

| Weak area | Review |
|---|---|
| Sensor placement and DMZ visibility | `labs/soc-dmz-foundation/` |
| Protocol/session metadata | `labs/soc-zeek-analysis/` |
| IDS alerts, signatures, and tuning | `labs/soc-suricata-ids/` |
| Session search, PCAP pivots, and retention | `labs/soc-arkime-pcap/` |
