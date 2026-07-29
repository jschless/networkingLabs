# Validation Record — `troubleshooting-range-dci-edge`

## Decision and frozen contract

**Result:** pass. Topology `1.0.0` was frozen on 2026-07-29 after the
load-bearing probe, clean build/deploy, 26/26 health, both reference-ticket
rubric walks, workaround rejection, idempotent no-restart reset, scoped
destroy/redeploy repeatability, resource compliance, and final cleanup.

This is the WP-16 range-B foundation only: exactly one T1 and one T3 are
installed. The other ten catalog rows remain planned. No human blind pilot is
claimed, rubric time bands remain provisional, and source topics are not
promoted to level 5 yet.

## Environment and images

| Item | Exact value |
|---|---|
| Date / owner | 2026-07-29 UTC / Codex |
| Base commit | `bc55f69da95acae2f5b14964f1582bbf387777cb` (`origin/main`) |
| Host | x86_64 Linux `5.15.0-181-generic`; 15 GiB RAM; 2 GiB swap |
| ContainerLab | 0.74.1, commit `1866b3a2b`, 2026-03-15 |
| Docker | client/server 29.5.3 |
| cEOS | `ceos:4.35.2F`; `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca`; EOS `4.35.2F-46221466.4352F` |
| Linux tools | `ops-lab:local`; `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`; Alpine 3.20.10, Python 3.12.13, iptables 1.8.10 |
| Carrier tools | `carrier-ethernet-tools:1.0.0`; `sha256:23da29b597935de5836b433a000ace6b16889522638a1a131639c51c01a92b33`; Debian 12.12, OVS 3.1.0 |

Build commands:

```text
docker build -t ops-lab:local images/ops-lab/
  0.75 s; max RSS 52,788 KiB; exit 0
docker build -t carrier-ethernet-tools:1.0.0 labs/carrier-ethernet-handoff/
  0.14 s cached; max RSS 52,528 KiB; exit 0
```

## Clean lifecycle

| Stage | Exact result | Wall time |
|---|---|---:|
| Clean deploy/readiness | `./range.sh deploy`; 21 nodes, 19 links, health 26/26 | 131.48 s |
| Green status | `./range.sh status`; all nodes running, health 26/26 | 2.18 s |
| T1 start | Healthy gate, QinQ fault, symptom proof, ticket only | 4.72 s |
| T1 minimal repair / verify | Replace only VLAN-120 NID-B mapping; verifier pass | 0.20 s verify |
| T1 workaround negative | Priority-200 OVS `NORMAL` restored apparent Silver service; verifier rejected it | expected failure |
| T1 reset / clear | Golden reset 26/26; clear succeeded twice | 27.58 s reset |
| T3 start | Healthy gate, ordered export-policy fault, symptom proof, ticket only | 3.83 s |
| T3 minimal repair / verify | Remove only stale route-map sequence, soft refresh; verifier pass | 0.92 s verify |
| T3 workaround negative | High-distance static tenant route left service apparent; verifier rejected it | expected failure |
| T3 reset / clear | Golden reset 26/26; clear succeeded twice | 27.60 s reset |
| First scoped destroy | No range container, network, link, generated lab directory, or SSH include | 4.33 s |
| Repeat deploy/status | Clean starting state, health 26/26 | 131.31 s deploy |
| Repeat destroy | Scoped cleanup clean | 4.70 s |
| Frozen deploy/status | Metadata pinned `1.0.0`; health 26/26 | 131.75 s deploy; 2.15 s status |
| Final destroy | Scoped cleanup plus attempt-state removal | 4.24 s |

All five cEOS containers retained their original `StartedAt` values and
`RestartCount=0` across faults and resets. Configuration replacement and Linux/
OVS restoration run in parallel; the approximately 27.6-second reset wall time
is dominated by real EVPN withdrawal/reconvergence and the end-to-end health
wait. It exceeds the 15-second non-convergence target only under the plan's
explicit protocol-convergence exception.

## Positive and negative coverage

The 26 health assertions prove local/inter-site EVPN sessions, external peering,
remote VTEP routes, bidirectional PROD applications, shared service, DEV
isolation, two approved peer routes, distinct Gold/Silver QinQ mappings,
1600-byte carrier acceptance, two 9000-byte storage paths and TCP sentinels,
inspected-origin success, direct-origin denial, default-deny policy, clean
scenario/qdisc state, and bounded clock skew.

Sanitized rubric evidence is stored in:

- `validation-artifacts/t1-carrier-svlan-map.md`
- `validation-artifacts/t3-dci-maintenance-policy.md`

The T1 verifier rejects broad bridge forwarding even when it masks the service
symptom. The T3 verifier requires an EVPN-derived VNI-50010 route and rejects a
static tenant route. Neither ticket permits container restart.

## Resources and targets

| Measurement | Result |
|---|---:|
| Frozen steady 21-container memory | 6,770.180 MiB / 6.612 GiB |
| Earlier steady sample | 6,701.935 MiB / 6.545 GiB |
| 38 reset samples | maximum 6,613.152 MiB / 6.458 GiB |
| Maximum observed across all snapshots | 6.612 GiB |
| Host available at frozen steady state | 6.4 GiB; swap unused |
| Range target | ≤8 GiB steady and ≥4 GiB host headroom: pass |
| Health target | 2.15–2.18 s, below 30 s |
| Frozen deployment | 131.75 s, including five cEOS boots |

The host cgroup layout did not expose a useful aggregate lifetime
`memory.peak`; peak is therefore the highest explicit aggregate snapshot, not a
kernel high-water mark.

## Repository and package gates

| Gate | Result |
|---|---|
| `scripts/validate_ticket.py` for both scenario directories | Both `OK — ticket contract validated` |
| Bash syntax / Python AST / topology YAML and shape | Passed; 21 nodes, 19 links |
| Range-local ShellCheck over controller, health, reset, and scenario scripts | Passed |
| `python3 scripts/lint-labs.py` | `OK — 143 labs checked, 52 distinct images, all consistent` |
| `./scripts/check-docs-admonitions.sh` | `OK: no malformed admonitions in docs/` |
| `mkdocs build --strict` | Passed; 22.55-second documentation build |
| `shellcheck -S warning scripts/*.sh labs/*/check.sh enterprise-it-101/eit.sh` | Passed |
| `python3 scripts/validate-enterprise-coverage.py` | `OK — 29 enterprise coverage topic(s) validated` |
| `./scripts/test-enterprise-coverage-validator.sh` | Positive fixtures passed and all five negative fixtures failed as required |
| `git diff --check` | Passed |

The first shakedown (excluded from the clean run above) found three issues:
missing OVS role environment caused exec-hook failure, the HTTP probe read only
one TCP chunk, and negated Bash pipeline status let an adversarial verifier
check continue. The role metadata, complete response reader, and explicit
negative branches were corrected before the recorded clean lifecycle. The
first strict docs build also rejected an over-deep wrapper include path; the
final strict build above uses the repository-standard path and passes.

## Limitations, rollback, and cleanup

- Live: standards-based cEOS EVPN/type-5 and route policy, cEOS external BGP,
  OVS userspace QinQ, Linux forwarding policy, exact-MTU packets, and TCP
  sentinels.
- Not claimed: vendor EVPN Multi-Site, L2 stretch/mobility, ESI/MLAG, hardware
  CFM/optics, real iSCSI/multipath, production WAF/NGFW, or live RPKI/IRR.
- The local image tags are existing repository build outputs. No new mutable
  third-party tag was introduced; exact validation IDs are recorded above.
- Rollback is scoped to this range directory and its docs registrations. Final
  cleanup removed every range container, management network, generated lab
  directory, SSH include, named link, and
  `/home/joe/.local/state/troubleshooting-range-dci-edge`. Shared images remain
  intentionally available to their source labs.
