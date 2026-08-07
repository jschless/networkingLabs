# Validation Record — `network-assurance`

## Status

**Passed — clean target deployment, complete learner walk, scoped negative
test, repair, repeatability run, repository gates, and cleanup completed by
the main validator on 2026-07-31.**

The requested `lab-tutor` skill was unavailable. No tutor validation is
claimed; this record is based on the main validator's live walk and review
against `labs/AUTHORING.md`.

## Environment

| Item | Validated value |
|------|-----------------|
| Owner and date | Codex main validator, 2026-07-31 |
| Host | Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab | `0.74.1`, commit `1866b3a2b` |
| Docker | client/server `29.5.3` |
| cEOS image | `ceos:4.35.2F`, ID `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca` |
| cEOS runtime | `4.35.2F-46221466.4352F` engineering build; build ID `6f39e5bb-e6c7-4637-b931-ecb30d43e034` |
| Endpoint image | `ops-lab:local`, ID `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7` |
| Assurance image | `assurance-lab:local`, ID `sha256:580aaa3cfc83cd416d21be8d45bf5803092adb227d6b3bd261988df60d4a6381` |
| Assurance base | `debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818` |

The assurance image built successfully with every direct package pinned. Its
runtime package set included `nfdump` 1.7.1, `softflowd` 1.1.0, `rsyslog`
8.2302.0, Net-SNMP 5.9.3, `tcpdump` 4.99.3, and `tini` 0.19.0.

## Clean deployment and service lifecycle

The final checked-in topology deployed cold in 24.16 seconds with exactly five
nodes. cEOS loaded the static localized SNMPv3 user, native logging, routed
interfaces, and the native monitor session from its startup configuration.
The two endpoint setup scripts, management setup, and sensor setup were each
executed a second time and remained idempotent: no duplicate addresses,
routes, listeners, collectors, or exporters appeared.

The first implementation draft correctly failed its sensor readiness check
because foreground `softflowd` does not write the requested PID file. The
final implementation records the supervised child PID itself and uses pinned
`tini` as PID 1. Two fault injections followed by repair twice left exactly
one supervisor and one `softflowd` exporter, with zero zombie, duplicate, or
stale exporter processes in the final image.

## Learner workflow evidence

The exact commands documented behind every task solution were exercised.

| Task | Live result |
|------|-------------|
| Trustworthy baseline | All five roles were running; all four EOS interfaces were connected; client-to-server ping returned 3/3; numeric SNMP identified `assurance-router` and mapped ifIndex 1/2 to Ethernet1/2; the monitor destination was active |
| Correlated event | A 2,000-packet, 1,400-byte ICMP payload burst returned 2,000/2,000; Ethernet1 `ifHCInOctets` rose from 2,893,260 to 5,603,064, a 2,709,804-byte delta; the bounded SPAN capture contained alternating requests/replies; NetFlow contained both directions with four-digit packet counts and about 2.7 MB each |
| Interface transition | The documented single multiline EOS CLI command shut Ethernet2; ping changed to 100% loss, numeric `ifOperStatus` changed to `2`, and native `%LINEPROTO-5-UPDOWN` syslog reported `down`; `no shutdown` restored ping and status `1`, with the matching native event |
| SNMP security comparison | The bounded six-packet capture exposed the v2c community, requested OID, and response value; the v3 exchange showed discovery plus visible engine/user metadata, while the authenticated/private scoped request and response were ciphertext |
| Hidden telemetry fault | Forwarding, SNMPv2c/v3, fresh native syslog, and fresh bidirectional SPAN capture remained healthy while only the external flow plane disappeared; the minimal sensor repair restored fresh records |

The small-versus-large flow boundary documented in the lab was also observed:
small bursts can remain in libpcap batching, while the bounded large burst plus
explicit cache expiry and five-second collector rotation was deterministic.
`nfdump -N` was required for unscaled integer byte totals.

## Checker, fault, and repair cycle

| Stage | Result |
|-------|--------|
| Final-image solved-state checker | 60 passed, 0 failed |
| Break-It execution twice | Both runs exited 0; no active exporter and no zombie process remained |
| Broken-state checker | 50 passed, 10 failed |
| Broken failure scope | Only `softflowd` health/arguments/control, fresh UDP/2055 export, the two flow directions, and their four packet/byte thresholds failed |
| Intentional SIGTERM during active NetFlow capture | Checker exited 143; no host `docker exec` capture process, in-container `timeout`/`tcpdump`, unique PID marker, or `/tmp` capture file remained |
| Repair execution twice | Both runs exited 0; exactly one supervisor and one `softflowd` exporter remained, with zero zombies |
| Repaired checker | 60 passed, 0 failed |
| Immediate repeat checker | 60 passed, 0 failed |

Every non-flow assertion passed in the broken state, including live forwarding,
numeric SNMPv2c/v3 queries, a fresh native EOS log marker, monitor-session
state, and a fresh SPAN request/reply capture. The additional assertion proved
that the fresh burst increased Ethernet1 `ifHCInOctets` by at least 2,000,000
bytes; it also passed while flow export was broken. The checker reaped both
bounded captures and removed their unique container PID markers and host
temporary files on normal and interrupted paths.

## Resource sample

The final solved-state point-in-time sample was:

| Node | Memory |
|------|--------|
| `router` | 1.14 GiB |
| `management` | 2.277 MiB |
| `sensor` | 1.629 MiB |
| `client` | 624 KiB |
| `server` | 620 KiB |

The sampled aggregate was approximately 1.15 GiB, within the 16 GB host
budget. This is a `docker stats --no-stream` sample, not a long-duration
high-water measurement.

## Repository gates

| Command | Result |
|---------|--------|
| Target Bash/POSIX shell syntax | Passed |
| Target ShellCheck at warning severity | Passed |
| Topology yamllint | Passed |
| `python3 scripts/check-markdown-spacing.py` | Passed |
| `./scripts/check-docs-admonitions.sh` | Passed |
| `python3 scripts/lint-labs.py` | Passed: 143 labs, 52 images |
| `python3 scripts/validate-quizzes.py` | Passed: 44 quiz/key pairs |
| `python3 scripts/test-validate-quizzes.py` | Passed: 7 regression cases |
| `git diff --check` | Passed |
| `mkdocs build --strict` | Passed |
| Tracked repository ShellCheck at error severity | Passed |

## Cleanup and boundaries

The final topology was destroyed with `./scripts/lab.sh destroy
network-assurance`. No matching containers, generated target directory,
`clab` Docker network, or bounded capture process remained.

This validation establishes local IPv4 routing, EOS SNMPv2c/SNMPv3 authPriv,
UDP syslog, native SPAN, and NetFlow v9 derived by one non-inline software
sensor. It does not establish native cEOSLab packet-flow export, production
credential strength, reliable UDP delivery, hardware SPAN oversubscription
behavior, IPv6, scale, or physical forwarding hardware. The packet and flow
planes deliberately share the SPAN feed; the lab makes that common failure
domain explicit rather than treating the evidence as fully independent.
