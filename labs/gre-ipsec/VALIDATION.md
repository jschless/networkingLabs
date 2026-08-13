# gre-ipsec — Validation Record

## Status

Main-orchestrator live validation, including the post-review implementation
follow-up, is complete. The remediated lab passed its fresh baseline, exact
solution and idempotence, bounded capture evidence, focused negatives,
polluted-state convergence, repeated deliberate confidentiality faults and
repairs, forced-TERM rollback, active-load checks, two accepted fresh
deploy/destroy cycles, and a fresh reviewer-specific validation cycle. The
healthy checker returns **128/0**. The current correlated checker returns
**91/37** for the supported deliberate fault; **103/25** is retained below
only as the historical pre-review checker signature for the same mechanism.

Validation, review, and repository gates are complete. The sole read-only
reviewer initially produced three findings; all three were fixed, received
post-review live evidence, and were closed by the same reviewer. The follow-up
was read-only, made no edit, did not deploy the lab, approved same-reviewer
closure, and returned exactly: `No actionable findings remain`. The lab tutor
was unavailable; `labs/AUTHORING.md` was the fallback authoring contract, and
no tutor validation is claimed.

## Environment

Validation ran on 2026-08-13 with this environment:

| Component | Observed value |
|-----------|----------------|
| Host | `x86_64`, Linux kernel `5.15.0-181-generic` |
| Docker client/server | `29.5.3` |
| ContainerLab | `0.74.1` |
| `vyos:local` | `sha256:74835bd5057d274fe0c8761c42e7a30a7a7e06aa8e2ccd050c0da82af3213495`, 2,264,851,359 bytes, amd64 |
| VyOS software | `2026.03.15-0031-rolling`, build commit `96ff51d3d2e559` |
| `ops-lab:local` | `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`, 68,762,000 bytes, amd64 |

The VyOS health state remained starting or unhealthy because the container
lacks the GRUB-style prerequisite expected by the packaged health check. This
known container health issue did not prevent native configuration, GRE, IKE,
child-SA or XFRM operation, captures, fault injection, or recovery. Every
container reported `OOMKilled=false`.

## Rejected development deployment and runtime fixes

The development deployment completed in 25.12 seconds with maximum command
RSS of 42,816 KiB. It began with exactly five intended nodes. Both WAN and LAN
directions worked through the preconfigured GRE scaffold, while IKE, child-SA,
and XFRM tables were empty. The bounded before-state capture showed raw GRE
and readable private ICMP. This deployment was rejected as an accepted final
cycle because it exposed two runtime defects:

1. The new bound helper scripts had host mode `0700`. The in-container
   `admin` user received permission denied before any mutation. All 15
   executable lab and configuration helpers were normalized to conventional
   mode `0755`.
2. The first checker after a correctly configured solution returned
   **118/10** because its XFRM patterns modeled a single-line rendering. The
   real `ip -s xfrm state` output places transport mode on an indented
   `proto esp ... mode transport` row. A policy selector ends in `uid 0`, and
   the policy's transport mode appears on the next indented protocol row. The
   checker and the break helper were changed to use exact UID-aware selector
   rows and multiline ESP transport rows. The same healthy mechanism then
   returned **128/0**.

## Development workflow after fixes

The complete solution produced matching exact live and saved definitions on
both gateways. Each gateway had:

- exactly one up IKE SA and one up child SA;
- IKEv2 with `AES_CBC_256`, `HMAC_SHA2_256_128`, and `MODP_2048`;
- child protection with `AES_CBC_256/HMAC_SHA2_256_128`;
- exact reciprocal public-WAN `/32[gre]` selectors;
- two directional XFRM states and two relevant GRE policies in transport
  mode; and
- positive counters with bidirectional host traffic.

The checker returned **128/0**. An immediate idempotent solution run again
returned **128/0**. Both the outer-only protected capture and the readable
inner `tun0` capture passed.

## Focused negative checks

Two reversible atomics tested exact checker isolation:

| Negative | Checker result | Isolation | Recovery |
|----------|----------------|-----------|----------|
| Change only `gw-b`'s saved ESP hash | **127/1** | Only the saved complete-definition assertion failed | Exact saved state restored; **128/0** |
| Delete only `gw-a`'s live remote-LAN route | **124/4** | Live route configuration, kernel route, and two host pings failed | Route restored; **128/0** |

The gateways were then polluted in both live and saved state: `gw-a` received
an extra IKE group named `EXTRA`, and `gw-b` received an extra ESP group named
`EXTRA`. The breaker precondition returned **124/4** and refused before
introducing `sha512`. The solution deleted and rebuilt both complete learned
subtrees, removed every extra from live and saved state, and embedded a
**128/0** checker result.

## Deliberate confidentiality fault and recovery

Two normal development fault cycles produced the identical historical
pre-review **103/25** checker result. Each fault changed only `gw-b`'s live
ESP hash to `sha512` and left both saved checksums unchanged. The exact
mechanism evidence was stable:

- far-public reachability passed in both directions;
- exactly one IKE SA remained up on each gateway;
- child-SA count and relevant GRE-policy count were both zero;
- host traffic continued in both directions;
- the bounded transit capture showed raw GRE and readable private ICMP with
  no ESP for the generated flow; and
- fresh `gw-a` logs contained `NO_PROPOSAL_CHOSEN`, `no CHILD_SA built`, and
  `keeping IKE_SA`.

| Run | Break | Break max RSS | Fault checker | Repair | Repair max RSS | Recovered checker |
|-----|-------|---------------|---------------|--------|----------------|-------------------|
| Development 1 | 26.73 seconds | 30,116 KiB | **103/25** | 20.56 seconds | 30,376 KiB | **128/0** |
| Development 2 | 27.66 seconds | 30,300 KiB | **103/25** | 19.89 seconds | 30,184 KiB | **128/0** |

An immediate idempotent repair completed in 18.93 seconds with maximum
command RSS of 30,348 KiB and embedded **128/0**. The protected capture then
passed.

Forced `TERM` was sent only after the exact live `sha512` value was observed.
The break helper exited 143, its transactional rollback embedded **128/0**,
restored live `sha256` and full service, preserved both saved checksums, and
reproduced the protected capture.

## Capture and process cleanup

As a capture-state negative, `capture-before.sh` was deliberately run in the
healthy protected state. It correctly exited 1 on ESP evidence rather than
claiming raw GRE. All nodes then reported zero `tcpdump` processes, and no
helper temporary files remained. No capture or traffic-flood process leaked
from any tested workflow.

## Active resources

Bidirectional protected pings ran at 0.02-second intervals while five Docker
statistics samples were collected:

| Node | Observed memory range |
|------|-----------------------|
| `gw-a` | 267.0–267.8 MiB |
| `gw-b` | 267.6–268.3 MiB |
| `host-a` | 756 KiB |
| `host-b` | 756 KiB |
| `internet` | 652 KiB |

Peak aggregate memory was approximately 538.2 MiB. Peak sampled per-node CPU
was 0.76%. Under load, the checker retained **128/0** and the ESP-only capture
passed. Zero ping processes remained afterward, and every container retained
`OOMKilled=false`. These are point-in-time samples, not capacity guarantees.

## Development cleanup

The development destroy completed in 1.33 seconds with maximum command RSS of
40,616 KiB and left a clean target state.

## Accepted fresh cycles

### Accepted cycle 1

- Deploy: 26.88 seconds, maximum command RSS 42,952 KiB.
- Unsolved baseline: zero IPsec/XFRM state and a passing raw-GRE capture.
- Solution: 25.06 seconds, maximum command RSS 30,120 KiB, embedded
  **128/0**.
- Healthy evidence: protected WAN and inner `tun0` captures passed.
- Break: 27.10 seconds, maximum command RSS 30,192 KiB, passing raw leak
  evidence and independent **103/25**.
- Repair: 19.88 seconds, maximum command RSS 30,196 KiB, embedded
  **128/0**.
- Destroy: 1.37 seconds, maximum command RSS 40,952 KiB.
- Residual state: no target containers, generated lab directory, or helper
  temporary file.

### Accepted cycle 2

- Deploy: 27.69 seconds, maximum command RSS 42,676 KiB.
- Unsolved baseline: zero XFRM state and a passing raw-GRE capture.
- Solution: 25.94 seconds, maximum command RSS 30,376 KiB, embedded
  **128/0**.
- Healthy evidence: protected WAN and inner `tun0` captures passed.
- Destroy: 1.44 seconds, maximum command RSS 41,256 KiB.
- Residual state: no target containers, generated lab directory, or helper
  temporary file.

## Repository gates and review

### Reviewer findings and remediation

The sole read-only reviewer identified three gaps:

1. Child algorithms, XFRM endpoints/mode, and positive counters were graded by
   independent global matches, allowing an unrelated record to satisfy a
   property missing from the expected record. The checker now flattens and
   validates records as units. It requires one total up child with the exact
   expected name and algorithms in that record; exactly two total ESP state
   blocks with one exact peer direction each, transport mode and positive
   current counters in each block; and exactly two GRE policy blocks with one
   exact peer direction and its own transport-mode ESP template each. Extra,
   duplicate, wrong-direction, or unrelated ESP/GRE records fail cardinality.
2. The prerequisite GRE and selected-route checks asserted leaf presence but
   described the scaffold as exact. The checker now compares normalized,
   complete live and saved `tun0` and selected-route subtrees with exact
   definitions, while ignoring unrelated route prefixes. Runtime learned-data
   interfaces also require exactly one intended IPv4 address. The README now
   states that `solution.sh` converges only the learned `vpn ipsec` subtrees
   and refuses to claim success when prerequisite scaffold remains polluted.
3. The Extensions section did not explicitly label its follow-ons as
   unvalidated. It now states that they are outside the validated workflow.

Synthetic multiline fixtures passed for healthy correlation and rejected a
wrong expected-child algorithm rescued elsewhere, an extra up child, a
zero-counter relevant state rescued by an unrelated counter, wrong mode
rescued by an unrelated state or policy, and duplicate/unexpected peer
state/policy blocks. A normalization fixture also proved that extra `tun0`
options and selected-route leaves change the exact comparison while an
unrelated route prefix is ignored.

### Post-review live validation

A fresh post-review deployment completed in 27.27 seconds with maximum
command RSS of 42,256 KiB. The exact solution completed in 26.74 seconds with
maximum command RSS of 30,528 KiB and embedded **128/0** under the new parser.
This real runtime proved:

- exact one-address runtime assertions;
- normalized complete live and saved `tun0` and owned-route subtrees;
- exactly one total and expected up child with algorithms in that same
  record;
- exactly two total and public-peer ESP state blocks, with transport mode and
  positive counters in each exact block; and
- exactly two total and public-peer GRE policy blocks, with transport-mode
  ESP templates in each exact block.

Two reviewer-specific live exactness negatives isolated the new prerequisite
checks:

| Negative | Checker result | Only failed assertions | Recovery |
|----------|----------------|------------------------|----------|
| Add only live `gw-a tun0` address `172.16.0.9/30` | **126/2** | `gw-a has only its exact tunnel address`; `gw-a complete tun0 subtree is exact in live state` | Remove the address; **128/0** |
| Add only a saved distance leaf under `gw-a` route `192.168.2.0/24` | **127/1** | `gw-a complete remote-LAN route subtree is exact in saved state` | Byte-for-byte restore; **128/0** |

The protected capture passed before the fault. A normal deliberate break
completed in 26.94 seconds with maximum command RSS of 30,120 KiB. It embedded
a **128/0** precondition and produced the required raw-GRE/private-ICMP leak.
The independent stricter correlated checker returned **91/37**. The mechanism
was unchanged from the pre-review **103/25** result; the new signature reflects
block-correlated and split assertions. Repair completed in 20.11 seconds with
maximum command RSS of 30,140 KiB and embedded **128/0**.

Forced `TERM` was repeated after the exact live `sha512` value was observed.
The helper exited 143, rollback embedded **128/0**, restored the healthy live
state, preserved unchanged saved state, and reproduced the protected capture.

Destroy completed in 1.53 seconds with maximum command RSS of 40,340 KiB. No
target container, generated lab directory, or helper temporary file remained.

The same reviewer completed a read-only follow-up without editing or deploying
the lab, approved closure of all three original findings, and returned exactly:
`No actionable findings remain`.

### Repository gates

Before the reviewer fixes, main ran and passed target Bash, ShellCheck, YAML,
and mode checks; markdown spacing; documentation admonitions; lab lint for
143 labs and 53 distinct images; all 44 quizzes plus 7 regression checks;
`git diff --check`; and strict MkDocs. The strict build completed in 28.37
seconds and emitted only the upstream Material warning and existing navigation
notices.

After reviewer closure, the final gate suite passed: target Bash syntax,
ShellCheck at warning severity, topology YAML, all 15 helper modes, markdown
spacing, documentation admonitions, lab lint for 143 labs and 53 distinct
images, all 44 quizzes plus 7 regression checks, `git diff --check`, and
strict MkDocs. The final strict build completed in 29.11 seconds with maximum
command RSS of 87,572 KiB. It emitted only the upstream Material for MkDocs
2.0 warning and existing navigation notices for `lab-remediation-status` and
two troubleshooting pages.

## Validation limits

Live validation did not cover arm64, physical VyOS appliances, hardware
cryptography or offload, NAT-T, long-duration rekey, induced packet loss, or
scale. Resource measurements are short, point-in-time observations rather
than capacity or stability guarantees. The results apply to the exact local
software images and versions recorded above.
