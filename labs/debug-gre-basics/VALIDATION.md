# debug-gre-basics validation record

## Status

Main-orchestrator live validation passed two pre-review clean cycles, exact
incident and healthy packet evidence, focused pollution negatives, repeated
fault/recovery, accepted `ERR`/`INT`/`TERM` rollback, interrupted-capture
cleanup, active resource sampling, and clean destroys. The reviewer then
requested stronger management, interface, and incident-state assertions. The
same implementation worker applied them, and main completed an accepted
current-code focused cycle: the incident checker is **71/7** and healthy state
is **78/0**. All **55/0** and **48/7** totals in the pre-review sections below
remain historical evidence rather than current expectations. Current-code
repository gates passed. The same reviewer closed all prior findings, returned
no new actionable findings, and approved the lab under the
`labs/AUTHORING.md` fallback.

`lab-tutor` is unavailable. `labs/AUTHORING.md` is the fallback instructional
contract; no tutor validation is claimed.

## Non-accepted diagnostic attempts

Three deployments found implementation defects rather than lab-platform
failures:

- The first exposed an awk `$2` expansion under `set -u` and a runtime-detail
  matcher that expected source-interface text absent from actual EOS output.
  The implementation worker corrected both, and main destroyed cleanly.
- The next exact incident helper passed, but the checker returned **50/5**
  because its EOS ping regex treated the suffix of `100% packet loss` as
  success. The implementation worker corrected all four matchers, and main
  destroyed cleanly.
- The first reviewer-fix deployment confirmed that all tightened canonical
  interface sections matched. Derived Linux management comparisons still
  assumed untrimmed route lines, and the checker invented cEOS `MGMT` default
  routes even though running and saved `ip route vrf` inventories were empty.
  The implementation worker normalized trailing line whitespace and required
  exact empty VRF-route inventories. Main destroyed cleanly.

These deployments are diagnostic history, not accepted validation cycles.

## Pre-review accepted clean cycle 1

### Fresh incident

`debug_gre_verify_state incident` returned status 0. Main observed:

- exact native `ceos:4.35.2F` gateways and three exact `ops-lab:local` roles;
- exact readiness markers and no target LAN-ingress DROP;
- accepted `tunnel source interface ...` declarations;
- only the `gw-b` destination wrong;
- both `Tunnel0` headlines up/up, with recursive-resolution detail on `gw-b`;
- reciprocal far public WAN endpoints reachable; and
- reciprocal tunnel and private-LAN traffic failing.

The healthy checker correctly rejected the incident with **48 passed / 7
failed**. The seven failures were the `gw-b` Tunnel0 declaration, `gw-b`
runtime endpoint, `gw-b` recursive condition, both tunnel directions, and both
LAN directions.

Initial saved startup SHA-256 values were:

| Node | SHA-256 |
|------|---------|
| `gw-a` | `366df00b1106ac342f2cfbb410f718e9dd2636c096f9beef33517057c9919396` |
| `gw-b` | `fb89b610f0aa9f430a9e6c0a44f214835a8531e4edde357f271c0a92d69a6a18` |

The fault capture returned status 0 with exact
`forward:reverse:requests:replies` counts **6:0:6:0** and no exact tcpdump
residue.

### Repair, idempotence, and healthy packet evidence

`repair.sh` reached **55/0**. `solution.sh` then ran twice idempotently, each
time reaching **55/0**. Both startup hashes remained unchanged.

The healthy capture returned status 0 with exact counts **6:6:6:6** and no
capture residue.

### Focused pollution negatives

Each negative was injected independently and restored to **55/0**. In every
case the checker returned **54/1**, `solution.sh` returned status 1 before
mutation, and the healthy `gw-b` destination remained `203.0.113.1`.

| Negative | Isolated rejected state |
|----------|-------------------------|
| Readiness | Bad `gw-b` readiness marker |
| Tunnel address | Secondary `172.16.0.6/30` on `gw-b` `Tunnel0` |
| Interface inventory | Extra `Tunnel99` on `gw-a` |
| Static-route inventory | Extra `198.51.100.0/24` via `203.0.113.2` on `gw-a` |
| Dynamic-routing bypass | OSPF process 99 on `gw-a` |
| Saved-state pollution | Extra saved route on `gw-b` |

The saved-state negative was restored to the exact original `gw-b` startup
hash.

### Deliberate fault, recovery, and transactional signals

Two normal break/repair cycles were identical:

| Run | Break | Incident helper | Fault checker | Repair |
|-----|-------|-----------------|---------------|--------|
| 1 | status 0 | status 0 | **48/7** | **55/0** |
| 2 | status 0 | status 0 | **48/7** | **55/0** |

Both startup hashes remained unchanged.

Accepted transactional evidence was:

- **ERR:** A one-shot in-memory Docker wrapper performed the real mutation and
  then forced status 97. `break.sh` reported
  `Transactional rollback restored the healthy state after ERR.` and the
  post-checker returned **55/0**.
- **TERM:** Main stopped the break process after observing the wrong live
  destination, queued TERM, and resumed it. The helper returned status 143,
  printed its explicit TERM rollback message, and restored **55/0** with both
  startup hashes unchanged.
- **INT:** In a later signal-specific clean deployment, the launcher reset an
  inherited ignored SIGINT. A one-shot exported Docker wrapper performed the
  real mutation and stopped the break process; main observed the wrong
  destination, queued INT, and resumed it. The helper returned status 130,
  printed `Transactional rollback restored the healthy state after INT.`, and
  restored **55/0**. Final saved state remained exact.

For transparency, earlier signal attempts were not accepted. A background INT
harness inherited ignored INT and completed normally, leaving **48/7** before
repair returned **55/0**. Earlier foreground immediate INT/TERM attempts may
have signaled while mutation was still in flight; both ended at **55/0**, but
lacked explicit rollback logs and therefore are not transactional evidence.

### Interrupted capture and active resources

Main sent TERM while the healthy capture's tcpdump was active. The helper
returned status 143 and left zero exact tcpdump, `setsid`, or helper processes;
the post-checker remained **55/0**.

Bidirectional active load sent 700 packets each way with 0% loss. Across six
Docker stats samples, observed peaks were:

| Node | Peak memory |
|------|-------------|
| `gw-a` | 1.123 GiB |
| `gw-b` | 1.13 GiB |
| `host-a` | 776 KiB |
| `host-b` | 764 KiB |
| `internet` | 656 KiB |

The aggregate observed peak was **2309.217 MiB (2.255 GiB)**. All five nodes
reported `OOMKilled=false`, restart count 0, running true, and no Docker health
check.

The final cycle-1 checker returned **55/0**, and both original hashes remained
unchanged.

### Cycle-1 cleanup

Clean destroy left:

- zero target containers;
- zero target Containerlab networks;
- zero generated lab directories;
- zero helper capture files; and
- zero target helper/capture processes.

## Pre-review accepted clean cycle 2

A fresh deployment returned status 0 from the exact incident helper and
**48/7** from the healthy checker. Fresh startup hashes were:

| Node | SHA-256 |
|------|---------|
| `gw-a` | `d3452ef11c4fc32a7e5607eb06dde49e5369ab3f222987d479ce2184dd5dda27` |
| `gw-b` | `3d75b1bf0f324d70479d76e3361166fa61e74d78f348cdec85020dd77c291a72` |

`repair.sh` returned **55/0**, idempotent `solution.sh` returned **55/0**, the
healthy capture returned status 0 with exact **6:6:6:6** counts, and the final
checker returned **55/0**. Both hashes remained unchanged.

Clean destroy again left zero target containers, networks, generated lab
directories, helper capture files, and target processes. The later accepted
INT diagnostic deployment was also destroyed with all five residue checks at
zero.

## Accepted reviewer-fix focused clean cycle

### Fresh current-code incident

The exact incident helper returned status 0. The strengthened checker returned
**71 passed / 7 failed**, retaining exactly the same seven causal failures:

- `gw-b` Tunnel0 canonical declaration;
- `gw-b` runtime endpoint;
- `gw-b` recursive-resolution condition;
- both reciprocal tunnel directions; and
- both reciprocal private-LAN directions.

Both incident Tunnel0 headlines explicitly matched up/up once each. The
tightened canonical interface sections all matched current EOS output.

### Focused reviewer negatives

Each negative was injected independently, rejected by the exact incident state
predicate, rejected by `repair.sh` before mutation, and restored to incident
status 0. In every case the wrong `gw-b` destination remained
`192.168.1.1` while pollution was present.

| Negative | State helper | Checker | Repair | Restore |
|----------|--------------|---------|--------|---------|
| Missing `gw-a` Tunnel0 description | status 1 | **70/8** | status 1 | status 0 |
| Explicit shutdown on `gw-a` Tunnel0 | status 1 | **69/9** | status 1 | status 0 |
| `192.168.2.10/32` bypass through the Docker management gateway on `host-a` `eth0` | status 1 | **69/9** | status 1 | status 0 |
| Extra `192.168.2.250/32` on `host-a` `eth0` | status 1 | **70/8** | status 1 | status 0 |
| Extra `host-a` management default via the Docker gateway with metric 100 | status 1 | Not claimed | status 1 | status 0 |
| Running `gw-a` non-`MGMT` VRF `ESCAPE` route to `Null0` | status 1 | **69/9** | status 1 | status 0 |
| Saved `gw-a` VRF `ESCAPE` route | status 1 | **68/10** | status 1 | status 0 |

The saved VRF-route negative was restored to the exact original startup hash.

### Current packet, repair, and lifecycle evidence

The current fault capture returned status 0 with exact
`forward:reverse:requests:replies` counts **6:0:6:0**. Minimal repair returned
the strengthened checker to **78/0**. Current saved startup SHA-256 values were:

| Node | SHA-256 |
|------|---------|
| `gw-a` | `e9217dd23107dbd376f898dce8c505bc2225cc85b8bd658c3e193695bb73bb65` |
| `gw-b` | `c8354dc26573aa8374b93b7cd12a69f2335a3e4e2af13db3d1e2538ae36d8c9e` |

Idempotent `solution.sh` returned **78/0**. The healthy capture returned status
0 with exact **6:6:6:6** counts.

A normal break returned status 0, the exact incident helper returned status 0,
the checker returned **71/7**, and both `gw-a` and `gw-b` Tunnel0 up/up evidence
counts were exactly one. Repair returned **78/0**.

Accepted current transactional evidence was:

- **ERR:** Real mutation followed by forced status 97 produced an explicit
  rollback message and restored **78/0**.
- **TERM:** A wrapper stopped immediately after real mutation and the wrong
  destination was observed. TERM produced status 143, an explicit rollback
  message, and restored **78/0**.
- **INT:** With inherited SIGINT reset to default, a wrapper stopped after real
  mutation. INT produced status 130, an explicit rollback message, and
  restored **78/0**.

Both final startup hashes remained exact.

### Current cleanup and resource scope

Clean destroy left zero target containers, target networks, generated lab
directories, helper capture files, and target processes.

The earlier active resource evidence remains applicable because the topology
and images did not change. It was not repeated as part of this focused
reviewer-fix cycle and is not presented as a new resource sample.

## Static and repository gates

Main's pre-review gate run passed and is retained as historical evidence. It
preceded the reviewer-driven implementation changes and is not used as the
current-code result.

Main then reran the complete applicable gate set against the final current
code:

- Target discovery found exactly 10 shell scripts; `bash -n` and ShellCheck at
  warning severity both passed.
- Exact YAML parsing, five-node inventory, and four-link inventory passed.
- Markdown spacing and docs-admonition checks passed.
- `lint-labs` passed with 143 labs and 54 distinct images.
- Quiz validation passed with 44 quiz/key pairs; its test suite passed all
  seven regression cases.
- `git diff --check` passed.
- `mkdocs build --strict` exited 0. Output contained only the existing Material
  for MkDocs 2.0 informational notice and existing non-nav notices for
  `lab-remediation-status.md`, `tracks/operations/troubleshooting-range.md`,
  and `tracks/operations/troubleshooting-range-advanced.md`.

## Same-reviewer closure

The same read-only reviewer closed all three prior findings:

- P1 management `eth0` and cEOS VRF-route exactness;
- P2 exact canonical declarations plus operational up/up state; and
- P2 incident up/up predicate coverage.

It returned no new actionable findings and found implementation, README,
capture, rollback, cleanup, and evidence boundaries consistent. Its read-only
bash syntax, ShellCheck, YAML, Markdown, and diff checks passed. Scope was clean
and `.claude` remained untouched.

Approval uses `labs/AUTHORING.md` as the fallback contract. `lab-tutor` remains
unavailable, and no tutor validation is claimed.
