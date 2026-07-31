# Validation Record — `acl-basics`

## Status

**Complete — clean live target walk passed.**

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-31, Codex |
| Host OS/kernel | Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab / Docker | ContainerLab `0.74.1` commit `1866b3a2b`; Docker client/server `29.5.3` |
| cEOS | `ceos:4.35.2F`, ID `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca`; NOS reports `4.35.2F-46221466.4352F (engineering build)` |
| Linux endpoints | `ops-lab:local`, ID `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`, 68,762,000 bytes |
| Linux base | `alpine:3.20` pinned to multi-arch OCI index `sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc`; selected amd64 manifest reports Alpine 3.20.10 |
| Repository base | `origin/main` at `d812c39d2448c44a0566f12250b0aff9c299f6a5`; validation working tree based on `eda13c9` |

## Feature-probe facts available

- cEOS accepted `counters per-entry`, the six-entry initial transit policy,
  and inbound attachment to Ethernet1 and Ethernet2.
- Initial policy outcomes were trusted ICMP and TCP/8080 permitted, trusted
  TCP/2222 denied, untrusted ICMP permitted, and both untrusted TCP services
  denied.
- ACL counters rendered `[match N packets, ...]`; configured and active
  attachment rendered `Et1-2`.
- Moving the ACL to inbound Ethernet3 opened the two sampled denied flows,
  left their earlier decision counters unchanged, and counted return traffic
  at sequence 60. Restoring the source-facing attachments repaired it.
- Inserting host-specific TCP/2222 permit sequence 45 produced the intended
  seven-entry final policy and final sampled flow outcomes.
- Sampled memory was 1.115 GiB for the router, 604 KiB for the client, 620 KiB
  for the attacker, and 23.65 MiB for the server (approximately 1.14 GiB
  aggregate).

See `PROBE.md` for the precise scope and limitations of those claims.

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Deploy | `./scripts/lab.sh deploy acl-basics`; one cEOS router and three Linux endpoints started cleanly | about 25 s | not sampled during startup |
| Baseline | Both server-local listeners, all six source/server paths, and unrelated client/attacker transit succeeded before policy | under 4 s | not sampled |
| Initial policy | README six-rule solution accepted; trusted ICMP/TCP-8080 passed, trusted TCP-2222 denied, untrusted ICMP passed, and both untrusted TCP ports denied | pass | included in sampled run |
| Counter evidence | Fresh traffic incremented initial sequences 10, 20, 30, 40, 50, and 60; attachment was configured and active on `Et1-2` | pass | included in sampled run |
| Break-It failure | `./labs/acl-basics/break.sh`; trusted TCP-2222 and untrusted TCP-8080 opened, earlier decision counters stayed unchanged, sequence 60 counted returns, attachment moved to `Et3` | pass (intended failure) | included in sampled run |
| Minimal repair | Removed only the Ethernet3 attachment and restored inbound Ethernet1/2 attachments; denied paths timed out again | pass | included in sampled run |
| Final exception/check | Added only sequence 45; untrusted host TCP-2222 opened while TCP-8080 stayed denied; checker passed 31/31 | about 22 s | final sample: router 1.102 GiB, client 612 KiB, attacker 608 KiB, server 19.56 MiB |
| Negative checker test | Wrong-interface helper caused 13 checker findings, including flow, attachment, interface-config, and counter-delta failures | pass (intended rejection) | included in sampled run |
| Final repair/recheck | Restored source-facing attachments; checker passed 31/31 again | pass | included in sampled run |
| Destroy/cleanup | `./scripts/lab.sh destroy acl-basics`; all four containers, host/SSH entries, and generated directory removed | 3.8 s | no residual containers |

The highest sampled full-topology value was the probe's approximately 1.14
GiB aggregate. The final solved sample was about 1.122 GiB aggregate and was
again dominated by cEOS.

## Positive and negative evidence

Positive assertions proven live:

- The two server-local controls separated service health from transit policy.
- Baseline routing allowed every intended test flow before ACL creation.
- cEOS accepted the exact hidden initial solution, enforced different ICMP and
  TCP decisions on the same ingress interface, and exposed per-entry counters.
- `Configured on Ingress: Et1-2` and `Active on Ingress: Et1-2` matched the
  source-facing topology.
- The final host-specific sequence 45 exception opened only attacker TCP/2222;
  the subnet-wide sequence 50 deny continued to block attacker TCP/8080.
- Before/after snapshots proved fresh increases on all seven final entries,
  including unrelated transit at sequence 60.

Negative assertions proven live:

- The wrong-interface fault opened both sampled deny paths without changing
  their earlier decision counters. Return traffic incremented sequence 60
  because only server-facing ingress remained attached.
- The final checker rejected that faulty state with 13 findings and returned
  to 31/31 after the minimal attachment repair.
- The three intended initial TCP denials and final two denials returned
  non-zero from `nc` while positive controls remained healthy.

## Repository gates

| Gate | Final result |
|---|---|
| `python3 scripts/check-markdown-spacing.py` | `OK: Markdown block spacing is valid` |
| `./scripts/check-docs-admonitions.sh` | `OK: no malformed admonitions in docs/` |
| `python3 scripts/lint-labs.py` | `OK — 143 labs checked, 52 distinct images, all consistent` |
| `python3 scripts/validate-quizzes.py` | `OK — 44 quiz/key pairs; totals, catalog metadata, remediation labs, links, and whitespace validated` |
| `shellcheck -S warning scripts/*.sh labs/*/check.sh` | Passed repository-wide |
| `git diff --check` | Passed |
| `mkdocs build --strict` | Passed; only existing informational notices for unnaved pages were emitted |

## Limitations, refresh, and cleanup

- The requested `lab-tutor` skill was unavailable; no tutor validation is
  claimed. `labs/AUTHORING.md` was used for student-flow review.
- TCP listener/connect behavior was tested, not application payload,
  authentication, TLS, IPv6 ACLs, fragment handling, scale, or physical ASIC
  behavior.
- cEOS is a licensed imported image. The exact tag, local image ID, and
  reported NOS version are recorded. Docker Scout is not installed, so no
  vulnerability scan result is claimed.
- The shared Linux endpoint image uses the digest-pinned Alpine 3.20.10
  multi-architecture index. Review again by 2026-08-31 or sooner for an
  actionable advisory.
- Final destroy removed all four containers, the generated lab directory,
  host entries, and SSH fragment. Matching container and directory checks
  returned absent.
