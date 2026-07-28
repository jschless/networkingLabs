# Data-Center Storage Networking Evidence Manifest

## Provenance and redistribution

WP-11/Codex created these two text fixtures on 2026-07-27 for this repository.
They are synthetic, reduced teaching evidence—not customer captures and not output
from Fibre Channel, DCB, RoCE, or array hardware. They contain no production names,
addresses, WWPNs, payloads, credentials, or personal data. The repository license
permits their redistribution.

## Capture method and versions

No hardware was captured. The records were authored from protocol field semantics
and internally checked as plain UTF-8 text. `sha256sum` from GNU coreutils 9.1 was
used for the checksums below. The reduction deliberately preserves event ordering
and cross-table identifiers while avoiding invented ASIC timing precision.

## Anonymization and residual risk

All identifiers use documentation-style locally administered values. There was no
source production data to anonymize. Residual disclosure risk is negligible; the
main risk is pedagogical misinterpretation, controlled by the synthetic labels in
every file and the fidelity notes below.

## Expected deductions

- `fc-login-zoning.txt`: trace initiator WWPN → FLOGI → name server → VSAN 111 →
  zone membership → target WWPN. The likely fault is a missing initiator member in
  the active zone set; an alternative is stale fabric distribution. The next safe
  step is a read-only active-zone comparison on both fabric switches.
- `roce-congestion.txt`: correlate rising queue depth, ECN marks, PFC pause time,
  and receiver CNPs. The likely fault domain is congestion control/queue design,
  not storage discovery. A pause storm, bad telemetry interval, or receiver issue
  remains an alternative. Validate switch queue/ECN configuration and host counters
  before changing PFC.

These deductions remain level-1 evidence. The files do not prove FLOGI/PLOGI,
zoning, VSAN/IVR, FIP, PFC, ECN, DCQCN, ASIC buffers, or array behavior live.

## Checksums

Run:

```bash
sha256sum labs/fixtures/dc-storage-networking/*.txt
```

Checksums are populated from the committed file contents:

```text
72c849e5441ea360bd76f3ddd31ba834340a88c688968a53ab9b599ec036bbed  fc-login-zoning.txt
f632dc1521b30214855d9c91766a5821f513e5fb1747c9648da92d19e144197c  roce-congestion.txt
```
