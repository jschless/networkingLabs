# Answer Key — Threat Intelligence and YARA Topic Quiz

**Total:** 30 points

## A1 — Indicator lifecycle (3 points)

- IPs are frequently shared/reassigned, domains can change ownership/content, and hashes
  are precise for one file but trivial to change; their decay and collision risks differ.
  (1)
- Operational records need source/provenance, first/last seen, confidence, context or
  malware/campaign relationship, handling restrictions, and review/expiry. (1)
- Detection severity/action should reflect confidence and asset/session corroboration,
  not convert every feed entry directly into a permanent block. (1)

## A2 — Content rules and evasion (3 points)

- Re-encoding, packing, string splitting, case/Unicode changes, or minor file edits evade
  a single literal. (1)
- Combine distinctive strings and hex/wildcard patterns with thresholds/relationships
  and file-format metadata/imports. (1)
- Conditions should constrain size/type/context and be tested against goodware and
  variants; broader resilience can also broaden false positives, so tuning remains
  necessary. (1)

## B1 — Two matches, different confidence (8 points)

1. The IP rule is low-confidence and stale with weak provenance; shared/reassigned
   infrastructure could create many false positives. Treat as enrichment or low-severity
   correlation until refreshed, not automatic blocking. (2)
2. YARA proves the extracted file contains the rule's benign lab marker and satisfies
   that rule. It does not prove malware, relation to the MISP event, execution, or host
   compromise. (2)
3. Award 1 point each for four relevant steps: refresh WHOIS/passive-DNS/feed context;
   check current reputation and first/last seen; correlate destination/session/asset;
   hash and identify the file; inspect provenance/extraction transaction; run additional
   static/sandbox/AV analysis; compare rule specificity/goodware corpus; or review host
   execution evidence. (4)

## C1 — Design an intel-to-detection pipeline (10 points)

- Ingest with schema, source, confidence, markings, timestamps, deduplication, and expiry.
  (2)
- Score by reliability, recency, indicator type, context, and internal sightings; require
  review for block/high-severity actions. (2)
- Generate scoped Suricata/other network rules and YARA content with stable IDs,
  references, versions, and expiration. (2)
- Unit-test syntax, known matches, variants, and representative benign corpora; canary
  deploy and monitor volume/performance. (2)
- Correlate matches with sessions/assets/files, feed analyst disposition back into score
  and tuning, and preserve versioned rollback/provenance. (2)

## D1 — A rule floods the SOC (6 points)

- Sample and group alerts by indicator/rule, asset, software signer/hash, destination,
  and time to identify the benign population and whether any distinct malicious cases
  coexist. (2)
- Narrow the rule with file type/path/signature/context, IOC confidence/age, or compound
  conditions; use scoped allowlists or thresholds for approved assets rather than global
  suppression. (2)
- Retain raw matches and aggregate counts with expiry/review on exceptions, canary the
  tuned rule, compare missed known-positive fixtures, and keep a versioned rollback.
  (2)

## Remediation

| Weak area | Review |
|---|---|
| IOC provenance, scoring, expiry, and rule export | `labs/soc-threat-intel-misp/` |
| File extraction, YARA conditions, evidence, and tuning | `labs/soc-yara-file-pipeline/` |
