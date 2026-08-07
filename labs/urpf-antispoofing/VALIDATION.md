# Validation Record — `urpf-antispoofing`

## Status

**Complete — clean live target walk passed.**

## Environment

| Item | Exact value |
|------|-------------|
| Date and owner | 2026-07-31, Codex |
| Host OS/kernel | Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab / Docker | ContainerLab `0.74.1` commit `1866b3a2b`; Docker client/server `29.5.3` |
| VyOS | `vyos:local`, ID `sha256:74835bd5057d274fe0c8761c42e7a30a7a7e06aa8e2ccd050c0da82af3213495`, 2,264,851,359 bytes; NOS reports `2026.03.15-0031-rolling`, build UUID `d26b303c-df41-45ac-831e-3ebc174a407b`, commit `96ff51d3d2e559` |
| Linux endpoints | `ops-lab:local`, ID `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`, 68,762,000 bytes |
| Linux base | `alpine:3.20` pinned to multi-architecture OCI index `sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc`; selected amd64 manifest reports Alpine 3.20.10 |
| Repository base | `origin/main` at `d812c39d2448c44a0566f12250b0aff9c299f6a5`; validation working tree based on `51ba2c6e4780c056a4192614cf3dfa333d7e2fad` |

## Feature-probe facts available

- cEOS 4.35.2F was tested first and reported uRPF unavailable on the local
  container hardware platform, so it was not used for the learned role.
- VyOS accepted strict and loose source validation on eth1 and rendered
  distinct nftables source-FIB rules with packet counters.
- Strict passed a legitimate source whose reverse route selected eth1,
  dropped an unrouted source, and dropped a source routed through eth2.
- Loose passed the known wrong-interface source, dropped a truly unrouted
  source without a main default, then passed it after a main default was
  installed.
- The supplied platform-probe sample was approximately 399.3 MiB aggregate.

See `PROBE.md` for the exact platform decision, commands, observations, and
limitations.

## Clean target walk

| Stage | Command/result | Time | Memory |
|------|----------------|-----:|-------:|
| Deploy | `./scripts/lab.sh deploy urpf-antispoofing`; one VyOS router and two Linux endpoints started from checked-in files | 15.06 s on final cold run | not sampled during startup |
| Initial-state audit | Correct addresses; `10.0.0.10/32` via eth1; no main default; management default only in VRF table 100; no eth1 source-validation rule | pass | not sampled |
| Disabled baseline | Immediate bounded capture saw `10.99.99.1 > 10.10.2.2` while the spoofed ping returned 100% loss, proving forward and return evidence are different | pass | included in final run |
| Strict mode | Legitimate `10.0.0.10` ping passed; unknown-source request stayed absent downstream; strict drop counter increased from 0 to 2 | pass | included in sampled run |
| Strict asymmetry | Temporary `10.99.99.0/24` route via eth2 remained blocked when the packet arrived on eth1 | pass | included in sampled run |
| Loose comparison | The same known wrong-interface source appeared downstream; truly unrouted `10.88.88.1` remained absent and increased the loose drop counter from 0 to 1 | pass | included in sampled run |
| Loose default caveat | Adding main `0.0.0.0/0` via `10.10.2.2` made `10.88.88.1` appear downstream; both experiment routes were then removed and strict mode restored | pass | included in sampled run |
| Final checker | Exact policy, configured and runtime routing, VRF separation, rule form, positive traffic, fresh counter delta, and bounded negative capture | 30/30; repeated 30/30 after repair | final sample: edge 252 MiB, attacker 608 KiB, internet 640 KiB |
| Runtime-route bypass | Added `10.99.99.0/24` directly to the kernel main table without adding VyOS configuration; checker rejected the live residue | 29 passed, 1 failed | intended rejection |
| Break-It | `./labs/urpf-antispoofing/break.sh` installed `10.0.0.10/32` via eth2; legitimate ping changed from success to 100% loss and strict drops increased from 8 to 10 | intended failure reproduced | included in sampled run |
| Negative checker | Faulty state returned non-zero with four targeted findings: correct-route config missing, wrong-route config present, installed route wrong, and legitimate traffic failed | 26 passed, 4 failed | included in sampled run |
| Minimal repair | Restored only `10.0.0.10/32` via `10.10.1.1`; checker returned to 30/30 | pass | edge 257.5 MiB, attacker 640 KiB, internet 788 KiB in that run |
| Destroy | `./scripts/lab.sh destroy urpf-antispoofing`; containers, generated lab directory, host entries, and SSH fragment removed | 1.23 s on final run | no residual containers |

The highest sampled full-topology value was the feature probe's approximately
399.3 MiB aggregate. The implemented final topology samples were lower and
were dominated by VyOS.

## Validation defects found and resolved

- The first immediate baseline capture preceded usable attacker-to-edge ARP
  state. Endpoint setup now uses a bounded 20-attempt gateway readiness loop;
  a final cold deploy handed off with the gateway neighbor reachable and the
  immediate spoof capture succeeded.
- VyOS installed routes include an optional `nhid` field. The checker now
  accepts that live rendering while still requiring the exact prefix, next
  hop, and interface.
- The first fault injector used Bash `errexit`, which conflicts with status
  values inside VyOS configuration functions. The injector no longer enables
  `errexit`; its wrapper independently verifies the installed wrong-route
  postcondition and refuses to report success otherwise.

## Positive and negative evidence

Positive evidence proven live:

- The management default remained in table 100 and never satisfied a
  data-plane source lookup.
- One-way capture proved the disabled baseline forwarded the spoof request
  even though the spoofed ping received no reply.
- Strict and loose modes produced the expected distinct nftables rule forms
  and fresh drop-counter changes.
- Strict preserved the legitimate alternate source when its best reverse
  route selected eth1.
- Loose accepted a source reachable through eth2 and, after a main default
  was added, an otherwise unknown source.
- The final checker passed all 30 assertions twice, including after a clean
  redeploy from the readiness-corrected checked-in files.

Negative evidence proven live:

- Strict blocked both an unrouted source and a source whose best reverse path
  selected the wrong interface.
- Loose without a main default blocked the truly unrouted source.
- The route-asymmetry helper caused a real legitimate-source outage and two
  fresh strict drops; the checker rejected it with four focused findings.
- A route injected directly into the kernel main table was rejected even
  though it was absent from VyOS configuration, closing the runtime-residue
  bypass identified in review.
- The wrapper's postcondition rejected earlier no-op injection attempts,
  preventing a false success claim.

## Repository gates

| Gate | Final result |
|------|--------------|
| `python3 scripts/check-markdown-spacing.py` | `OK: Markdown block spacing is valid` |
| `./scripts/check-docs-admonitions.sh` | `OK: no malformed admonitions in docs/` |
| `python3 scripts/lint-labs.py` | `OK — 143 labs checked, 52 distinct images, all consistent` |
| `python3 scripts/validate-quizzes.py` | `OK — 44 quiz/key pairs; totals, catalog metadata, remediation labs, links, and whitespace validated` |
| `shellcheck -S warning scripts/*.sh labs/*/check.sh` | Passed repository-wide |
| `git diff --check` | Passed |
| `mkdocs build --strict` | Passed; only existing informational notices for unnaved pages and the upstream Material/MkDocs notice were emitted |

## Limitations, freshness, and cleanup

- The requested `lab-tutor` skill was unavailable; no tutor validation is
  claimed. `labs/AUTHORING.md` was used for the learner-flow review.
- The lab validates IPv4 source checking on one software-forwarded VyOS
  Ethernet ingress. IPv6, ECMP, policy routing, scale, fragments, and
  physical forwarding hardware were not tested.
- VyOS is a locally imported rolling image built 2026-03-15. Review it again
  by 2026-08-31 or sooner for an actionable security or compatibility issue.
- The shared Linux endpoint image uses the digest-pinned Alpine 3.20.10
  multi-architecture index. Review it again by 2026-08-31 or sooner for an
  actionable advisory.
- Final destroy left no matching lab containers or generated lab directory.
