# Answer Key — SIEM and Incident Response Topic Quiz

**Total:** 30 points

## A1 — Normalize without erasing meaning (3 points)

- Map Zeek `id.orig_h` and Suricata `src_ip` to a common source-address field and
  normalized time/network tuple while retaining product/event type. (1)
- Map YARA's file path to a file/path observable with hash/rule fields rather than
  forcing it into a network-only schema. (1)
- Preserve raw event, sensor/tool, parser/version, ingest/event timestamps, and source
  field names so normalization remains reversible and provenance survives. (1)

## A2 — Dashboards and cases (3 points)

- A dashboard summarizes monitoring signals; a case preserves scoped hypotheses,
  evidence, actions, ownership, observables, decisions, and timeline. (1)
- Award 2 points for three valid dashboard blind spots: averaging hides a spike; wrong
  or delayed time window; top-N drops a low-volume attack; counts omit severity/asset
  criticality; ingestion/parser failure appears as zero; aggregation merges distinct
  sources; or a “green” availability metric does not measure compromise. (2)

## B1 — Reconstruct the timeline (8 points)

1. The note claims isolation at 12:01, but later packet evidence at 12:07 shows outbound
   traffic. Possibilities include inaccurate/manual note time, delayed/incomplete
   containment, traffic from another interface/NAT identity, clock skew/time-zone error,
   or queued event ingestion. (3)
2. Establish device/firewall isolation command and audit timestamps, synchronized clocks
   and time zones, interface/link/state logs, packet sensor event time versus ingest time,
   and the exact bastion identity/five-tuple. (3)
3. Preserve the original note, add a correction/addendum with author/time/evidence, and
   record the containment interval/confidence as unknown or bounded until resolved; never
   silently edit history. (2)

## C1 — Work the incident end to end (10 points)

- Validate and scope the alert with correlated network, packet, file, identity, and asset
  evidence; document hypotheses and confidence. (2)
- Hash/preserve originals, clocks, collection paths, handlers, and copies for chain of
  custody before volatile evidence disappears. (2)
- Contain narrowly according to business risk while recording exact action/time and
  verifying both effectiveness and unintended impact. (2)
- Track observables, tasks, owners, decisions, and a source-cited timeline; make queries
  and evidence references reproducible by a second analyst. (2)
- Define eradication and recovery gates, monitor recurrence, then update detections,
  controls, runbooks, and lessons with a retest. (2)

## D1 — Turn adversary simulation into a finding (6 points)

- Map every simulated step to its expected telemetry and separately document which steps
  were designed to alert versus only log/support correlation. (2)
- A true gap exists when required sensor/log coverage is present and a validated
  alerting expectation fails, not merely because every step lacks an alert. (1)
- Record technique, test input, affected controls, observed artifacts, expected
  detection, severity based on attack path/asset, and evidence limitations. (1)
- Prioritize missing high-impact/low-visibility stages, implement content or collection
  changes in a versioned test environment, and rerun the contained sequence with positive
  and false-positive checks—never against unauthorized live targets. (2)

## Remediation

| Weak area | Review |
|---|---|
| Normalization and multi-source ingest | `labs/soc-elk-ingest/` |
| Dashboard queries, aggregation, and HVT visibility | `labs/soc-kibana-hvt-dashboard/` |
| Case evidence, observables, timeline, and response workflow | `labs/soc-ir-case-management/` |
| Detection coverage and controlled adversary simulation | `labs/soc-adversary-simulation/` |
