# Troubleshooting Range Assessment Guide

The supervisor deploys the range, confirms health, blind-draws tickets, opens
only transcript-wrapped node sessions for the engineer, then scores the rubric
and verifier result. Rubrics are internal plaintext by design; do not share
them with an engineer during an active attempt.

## Proposed qualification bands

| Tier | Draw | Time band | Pass rule |
|---|---:|---:|---|
| T1 | 3 tickets | ≤15 min each | ≥70% and verifier passes on each |
| T2 | 3 tickets | ≤35 min each | ≥70% and verifier passes on each |
| T3 | 3 tickets | ≤60 min each | ≥70% and verifier passes on each |

These are starting values pending the pilot; record actual timing in the plan.
Shotgun changes, unverified fixes, and symptom-masking workarounds receive the
red-flag caps stated in each rubric regardless of raw points.

## Runbook

```bash
./range.sh deploy
./range.sh start --tier 1
# Hand only the displayed ticket to the engineer.
# Engineer uses: ./range.sh shell <node>
./range.sh attempt show
# After the engineer says they are done:
./range.sh verify
./range.sh reset
```

The attempt directory records ticket copy, start/stop metadata, and one
`script(1)` output/timing pair per node session. Review it alongside the
engineer’s write-up and rubric.
