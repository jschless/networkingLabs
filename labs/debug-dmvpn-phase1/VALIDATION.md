# debug-dmvpn-phase1 — Validation Record

## Status

Final-code live validation and two clean deployment/destroy lifecycles are
complete below. Target and repository gates are also complete, with the
unrelated repository-wide VyOS footer baseline isolated below. Read-only
review is complete with no actionable findings. This evidence intentionally
makes no self-referential commit claim; Git history provides the implementation
identity, which the subsequent ledger-only entry records.

The lab tutor is unavailable. Validation will use `labs/AUTHORING.md` as the
fallback authoring contract and will not claim tutor validation.

## Environment and platform ownership

The accepted deployments used this ownership model:

| Role | Intended platform | Responsibility |
|------|-------------------|----------------|
| `hub`, `spoke1`, `spoke2`, `spoke3` | Native `vyos:local` | mGRE, NHRP, OSPF, route installation, and learner repair |
| `br-wan` | Incidental `ops-lab:local` | Ethernet bridging and bounded observation only |

## Rejected implementation deployments

### First deployment — omitted normalized leaf

The first edited deployment was rejected before acceptance. Although the
pre-migration spoke1 source contained the intended static map to
`10.0.0.254`, the source omitted spoke `registration-no-unique`. Current-image
boot migration then added `registration-no-unique` to every spoke and removed
every spoke `map` leaf. Generated spoke1 `/config/config.boot` and live state
therefore contained the correct NHS and multicast target, the normalized
registration leaf, and no static map. Its operational NHRP row appeared as a
correct `nhs` row to `10.0.0.1`, and service traffic passed, so the saved
incident had been erased rather than validated.

Main also reconfirmed that changing only the NHS while a correct mapping is
cached is not immediately causal. The selected static-map fault remains the
design.

### Second deployment — explicit normalized leaf

The second edited deployment added explicit `registration-no-unique` to all
three spoke source configs and exact expectations. That alone did **not**
preserve a source map: current-image migration again stripped every spoke map.
At approximately 55 seconds, live spoke1 still had no map, so its intended
one-leaf incident was absent and service traffic remained healthy. This cycle
was also rejected and cleanly destroyed.

### Third deployment — strict-mode ordering

The third deployment ran the bounded startup normalizer on all three spokes.
Every helper reached base live/saved readiness, then exhausted five failed map
attempts. Main traced one attempt with `/bin/vbash -x`: `set-map.sh` enabled
`set -euo pipefail` before sourcing
`/opt/vyatta/etc/functions/script-template`. The current template returns a
benign nonzero during shell-function setup, so `errexit` aborted before
`configure`.

ContainerLab logged each spoke exec with `rc=1` but returned overall deploy
status 0. All exact readiness markers were absent and all live/saved maps were
absent, so state/check acceptance would fail even though the deploy command
did not. The deployment was rejected and cleanly destroyed. That iteration
moved strict mode after template sourcing. Marker grading remains mandatory
because this ContainerLab version does not propagate topology exec failure to
its process status.

### Fourth deployment — VyOS `set` alias

The fourth deployment reached the shared mutator after template sourcing but
again produced no maps or readiness markers. `/bin/vbash -x` showed that the
VyOS template aliases `set` to its configuration command. Consequently,
`set -euo pipefail` invoked `vyatta_cfg_run set -euo pipefail` instead of the
Bash option builtin, disturbed positional arguments, emitted helper usage, and
exited 127. All three topology execs were logged as `rc=1`; the deployment was
rejected and cleanly destroyed.

The fourth-iteration fix invoked `builtin set -euo pipefail` after template
sourcing to bypass the alias. Later cycles retained explicit argument handling
but proved that strict mode itself had to be removed from the native mutator.

### Fifth deployment — template positional parameters

The fifth deployment used `builtin set` successfully but still emitted helper
usage and produced no maps or readiness markers. Manual tracing showed that
the sourced VyOS template had already clobbered `$1` and `$2`; after strict
mode was enabled, `${1:-}` was empty and the helper exited 127. The deployment
was rejected and cleanly destroyed.

The fifth-iteration fix validated and copied target/persistence arguments and
completed all `$#` checks before sourcing the template. Later cycles retained
that argument ordering while removing incompatible strict mode from the inner
native mutator.

### Sixth deployment — absent native delete

The sixth deployment entered native configuration mode with correct saved
arguments and strict-mode ordering, but every helper stopped at `delete ... ||
true`. Because migration had removed the map, the native command printed
`Nothing to delete` and returned status 1 from within the vbash configuration
context before the intended `set`. No live/saved maps or readiness markers
were created. The deployment was rejected and cleanly destroyed.

Main manually proved the exact replacement behavior without `delete`:

- when the map was absent, one scalar `set ... nbma "$target"` added it and
  `commit`/`save` persisted it successfully; and
- with an existing `.254` map, a live-only scalar `set` to `.1` atomically
  replaced live state while the saved map remained `.254`.

The shared helper now omits `delete` entirely. Startup normalization uses the
same proven scalar operation with `--save`; repair and break use it without
save, preserving their nonpersistent contract.

### Seventh deployment — native alias return status

The seventh deployment reached the exact scalar
`vyatta_cfg_run set protocols ...` operation and then exited status 1 without
creating a map. Filtered vbash tracing showed that valid native VyOS
configuration aliases can return benign nonzero values; shell `errexit` is
therefore incompatible with this inner helper even after argument and template
ordering are correct. Maps and markers remained absent, so the deployment was
rejected and cleanly destroyed.

Main manually proved the standard sibling VyOS helper pattern without strict
shell mode: it added and saved an absent map successfully, then replaced an
existing map live-only while saved state remained unchanged. `set-map.sh` now
uses that accepted native sequence—explicit argument validation/copy before
source, then source, `configure`, scalar `set`, `commit`, optional startup
`save`, and `exit`—without `errexit`. The external startup normalizer remains
strict and requires exact live/saved postconditions; repair and break also
enforce exact state and saved-hash postconditions.

The corrected design retains the platform-normalized registration leaf on all
spokes and adds a uniform bounded post-migration helper. After native
live/saved readiness succeeds, the helper applies each intended map through
VyOS, commits and saves it, and verifies the exact map in both live state and
`/config/config.boot` before returning. Spoke1 receives the incident value;
spokes2/3 receive the healthy value. A timeout, failed native operation, or
verification mismatch returns nonzero from the topology exec and is logged.
The exact readiness marker is separately graded because current ContainerLab
does not propagate that exec failure to the deploy process status. Runtime
repair and break remain live-only and never use the helper's startup-only save
mode.

The only intended incident/healthy difference remains spoke1's static map
value.

Main cleanly destroyed all seven rejected deployments. They contribute
platform/helper evidence only: they provide no accepted incident, healthy,
checker-total, resource, reviewer, or closure claim. Corrected final-code live
validation is recorded in the accepted cycles below.

## Eighth-cycle accepted behavior discovery

The eighth deployment became the first accepted complete lifecycle, distinct
from the seven rejected engineering deployments. Bounded startup normalization
succeeded on all three spokes: live and saved maps were exact and all three
exact readiness markers were present.

Fresh incident observation established:

- exact four-row hub NHRP with dynamic spoke1 registration, and spoke1's exact
  static hub map to `.254`;
- three hub OSPF rows—spoke1 `ExStart/DROther`, spokes2/3 `Full/DROther`—and
  exactly one `ExStart/DROther` hub row on spoke1;
- only spoke2/3 service and overlay OSPF routes on the hub;
- no remote overlay or service OSPF routes on spoke1;
- only the other unaffected spoke's service/overlay route on spokes2 and 3;
- healthy underlay, exact NHRP, and healthy spoke2↔spoke3 paths, with spoke1
  overlay/service isolation.

This is causal current-image behavior: OSPF hello multicast discovers the
peer, but unicast database exchange follows the bad map and stalls in ExStart.
It replaces earlier expectations that spoke1 remained Full with routes.

The same observation exposed exact legitimate kernel host-route rendering
without `/32`: NHRP rows use known overlay hosts, numeric `nhid`, `tun0`,
`proto nhrp`, and metric 20 with no `onlink`; OSPF overlay/service routes omit
the suffix where applicable and end in mandatory `proto ospf metric 20
onlink`. The corrected pollution predicate permits only exact known
destination/next-hop/interface/protocol/metric/`onlink` shapes and retains
fail-closed handling for every other row.

No checker total, repair, capture, resource, reviewer, destroy, or closure
claim was made at that observation point for the then-live eighth cycle.

The strengthened healthy checker subsequently returned **108 passed / 28
failed** against the exact fresh incident. The failures are the expected
healthy-state assertions downstream of spoke1's wrong live map, ExStart
adjacency, absent spoke1 routes, and isolated overlay/service paths; incident
state itself passed its separate exact predicate.

The first fault-capture attempt collected 20 duplicated bridge-wide ARP
requests for `10.0.0.254` from `10.0.0.11` and no reply, but was rejected as
accepted helper evidence because its parser expected the non-`-e` text form
`ARP, Request`. With `tcpdump -e -i any`, the observed stable substring was
`ethertype ARP (0x0806), length 48: Request who-has 10.0.0.254 tell
10.0.0.11`. The corrected parser allows variable capture-interface/MAC prefix
and numeric frame length while requiring that exact ethertype, action, and IP
identity; it still requires at least one request and exactly zero replies. A
later corrected capture run passed and is recorded below; the rejected parser
attempt is not claimed as a helper pass.

### Rejected cached-adjacency re-arm and accepted reset probe

The first normal `break.sh` re-arm from exact health applied the one live map
fault successfully, but the established OSPF adjacency remained Full. The
50-iteration exact incident loop could not converge because no event forced
the cached relationship to rebuild over the newly broken unicast mapping.
Main interrupted this rejected path with `Ctrl-C`. Transactional rollback
restored exact health, the outer healthy checker passed **136/0**, and the
break helper returned the required signal status 130.

Main then applied the same one-leaf live map fault and ran a spoke1-only
operational `/usr/bin/vtysh -c 'clear ip ospf process'`. After 12 seconds,
hub/spoke1 were exact `ExStart/DROther`, spokes2/3 remained `Full/DROther`,
NHRP remained exact, and the complete incident predicate returned 0. This is
accepted mechanism evidence: the operational clear changes no configuration
and performs no save; it only removes a stale live adjacency so repeat re-arm
matches fresh deployment behavior.

`break.sh` now runs that command under a 10-second bound immediately after the
single map mutation and before its post-mutation test hook. Any nonzero status
or timeout propagates through `ERR` into the existing transactional rollback.

The corrected normal re-arm then completed with `BREAK_RC=0`; the exact
incident predicate returned 0, and the healthy checker on that incident was
again exactly **108 passed / 28 failed**. All four repository source
configuration hashes were unchanged (observed prefixes: hub `137933`, spoke1
`035327`, spoke2 `afc9d5`, spoke3 `f629f8`).

### Atomic repair-precondition negatives

Six reversible one-at-a-time probes began from the exact incident. In every
case `repair.sh` returned 1 before mutation and the target spoke1 live map
remained `10.0.0.254`:

| Atomic pollution | Repair result | Mutation guard evidence | Cleanup observation |
|------------------|---------------|-------------------------|---------------------|
| Spoke2 OSPF `interface eth1 passive` | `rc=1` | Target map remained `.254` | Removing the leaf left an empty interface node; exact cleanup deleted the complete `interface eth1` node |
| Spoke2 `dum1 198.18.0.1/32` | `rc=1` | Target map remained `.254` | Removed the extra interface |
| Spoke2 static `198.51.100.0/24` via `tun0` | `rc=1` | Route was present in the kernel; target map remained `.254` | Removing the route left an empty parent; exact cleanup deleted complete `protocols static` |
| Spoke2 extra `eth0 198.18.0.2/32` | `rc=1` | Target map remained `.254` | Removed the extra management address |
| Hub NHRP `redirect` | `rc=1` | Phase 2 pollution rejected; target map remained `.254` | Removed the redirect leaf |
| Saved-only spoke2 `dum0` description `Saved pollution`, live restored exact | `rc=1` | Helper explicitly reported saved configuration mismatch; target map remained `.254` | Runtime saved SHA prefix changed `8b874e` → `861030`, then bounded-backup byte restore returned it to `8b874e` |

These are six precondition rejection results, not checker atomic totals. After
each cleanup the next probe began from exact incident state; after all six,
the complete incident predicate returned 0. The two empty-parent observations
are current-image cleanup behavior and explain why deleting only the injected
leaf was insufficient for exact recovery.

### Transactional rollback after real mutation

The corrected break helper was exercised after both its real live map mutation
and spoke1 operational OSPF reset:

| Path | Trigger evidence | Helper result | Independent recovery proof |
|------|------------------|---------------|----------------------------|
| `ERR` | Test-only hook ran after mutation/reset | `rc=1`; trap printed exact-health restoration | Healthy predicate `rc=0` |
| `TERM` | Pause marker observed after mutation/reset; exact break PID received `TERM` | `rc=143`; trap restored exact health | Healthy predicate `rc=0` |
| `INT` | Pause marker observed after mutation/reset; PTY received `Ctrl-C` | `rc=130`; trap restored exact health | Healthy predicate `rc=0` |

The normal corrected re-arm already returned 0 and reached exact incident
state. These results prove transactional recovery for every supported failure
or signal path after the actual mutation boundary; they are not pre-mutation
trap tests.

### Interrupted capture cleanup

During a healthy-mode capture, the monitor observed the lab-local `tcpdump`
child active. Main sent `INT` to the exact host `bash ./capture.sh healthy` PID
3094557. The capture helper exited 130 and emitted no output. Post-interrupt
cleanup found:

- zero `tcpdump` processes in `br-wan`;
- zero host capture or `setsid` helpers; and
- zero `/tmp/debug-dmvpn-phase1.*` files.

This proves signal cleanup for the interrupted healthy capture. It does not
replace the separate accepted full fault and healthy capture runs recorded
below.

### Active-load resource observation

Main ran six simultaneous bidirectional source-specific service pings,
covering both directions of every spoke pair, and collected six Docker stats
samples during that traffic.

| Node | Maximum sampled memory | Running | OOM killed | Restart count | Docker health |
|------|------------------------|---------|------------|---------------|---------------|
| `br-wan` | 660 KiB | true | false | 0 | No healthcheck |
| `hub` | 263.8 MiB | true | false | 0 | `unhealthy` (`atopacct` boundary) |
| `spoke1` | 267.1 MiB | true | false | 0 | `unhealthy` (`atopacct` boundary) |
| `spoke2` | 268.0 MiB | true | false | 0 | `unhealthy` (`atopacct` boundary) |
| `spoke3` | 264.3 MiB | true | false | 0 | `unhealthy` (`atopacct` boundary) |

The maximum aggregate sampled sum was approximately 1063.8 MiB (1.04 GiB).
The four VyOS Docker-health results reflect only the documented image
`atopacct` boundary and are not learner-state failures. After load, cleanup
found zero ping or `tcpdump` processes and zero target temporary files. This
is a bounded six-sample observation, not a capacity or long-duration
stability claim.

## Accepted lifecycle cycles

### First-cycle clean destroy

After all accepted checks and the active-load observation, main ran:

```text
containerlab destroy -t topology.clab.yml --cleanup
```

The command returned 0 and removed all five target containers, generated host
entries, and generated SSH config. The generated ContainerLab directory was
absent, with zero target containers, target networks, target temporary files,
or helper processes. The initial count formatter rendered a blank field for a
zero count; independent filesystem and runtime checks established the zero
postconditions.

### Second-cycle fresh incident

A second clean deploy returned 0 and created all declared links. Every startup
normalizer printed verified live and saved target state:

| Spoke | Verified live target | Verified saved target |
|-------|----------------------|-----------------------|
| `spoke1` | `10.0.0.254` | `10.0.0.254` |
| `spoke2` | `10.0.0.1` | `10.0.0.1` |
| `spoke3` | `10.0.0.1` | `10.0.0.1` |

The fresh exact incident predicate returned 0. The corrected standalone fault
capture also returned 0 and reported 19 packets: 15 unanswered ARP request
records for `.254`, zero `.254` replies, and exact protocol and route incident
proof.

### Second-cycle repair and healthy state

Repair returned 0. The healthy checker passed **136/0**, including its
embedded healthy capture. Before/after container saved-configuration hashes
were unchanged:

| Node | Unchanged hash prefix |
|------|-----------------------|
| `hub` | `cf78af5c...` |
| `spoke1` | `c1e3fd27...` |
| `spoke2` | `5f43fd47...` |
| `spoke3` | `ac985919...` |

The standalone healthy capture returned 0 with exactly eight packets, both
hub-facing GRE legs, and no direct spoke leg. The second cycle therefore has
accepted clean-deploy, incident, repair, checker, and capture evidence.

### Second-cycle clean destroy

Main ran:

```text
containerlab destroy -t topology.clab.yml --cleanup
```

The command returned 0 and removed all five containers plus the generated
host entries and SSH config. The final exact audit reported
`TARGET_CONTAINERS=0`, `TARGET_NETWORKS=0`, no generated ContainerLab
directory, and no `/tmp/debug-dmvpn-phase1.*` files. The process audit emitted
only its audit shell self-match; there was no actual target helper or capture
child. This completes the second accepted clean deployment/destroy lifecycle.

The lab therefore has two accepted clean deployment/destroy cycles. They are
separate from the seven rejected, cleanly destroyed engineering deployments
documented above.

## Focused negative coverage

The exact predicates and mutation preconditions cover:

- an extra/missing live learner-owned NHRP or OSPF leaf;
- an extra live or saved interface/address;
- an out-of-scope management route or address;
- a static or alternate-dynamic route bypass;
- redirect, shortcut, fixed-remote, or asymmetric spoke normalization;
- a stale passive `eth1` or hub-owned remote service advertisement; and
- saved-state drift while live state otherwise appears healthy.

The six accepted reversible atomic probes, their causal failures, cleanup, and
post-cleanup incident result are recorded above. No contaminated runtime from
the observed empty-parent platform behavior was retained as accepted evidence.

## Accepted cleanup evidence

Normal re-arm and forced `ERR`, `INT`, and `TERM` rollback after real mutation
are complete above. Interrupted healthy capture cleanup is also complete.
Both full capture modes are complete. Both accepted deployment cycles ended in
clean destroy with zero target containers and networks, no generated
ContainerLab directory or target temporary files, and no actual target helper
or capture child. The final process audit's only match was its own audit shell.

## Repository gate evidence

Final target gates passed:

- Bash parsing for every target `.sh` file;
- ShellCheck at warning severity;
- exact YAML parsing with five nodes, four links, and intended images;
- Markdown spacing; and
- `git diff --check`.

Repository gates also passed:

- documentation admonitions;
- lab lint across 143 labs and 53 distinct images;
- quiz validation for 44 quizzes;
- seven quiz regression cases;
- the enterprise coverage positive/negative fixture contract with 29 topics,
  three fixture topics, and the expected negative-fixture failures; and
- `mkdocs build --strict`, which returned 0 in 28.88 seconds with only the
  existing Material 2.0 banner and known non-navigation pages.

Repository-wide `validate-vyos-configs.sh` returned 1 solely for 14 unrelated
existing labs that lack the newer footer convention: six `black-core`, two
`gre-ipsec`, two `ipsec-basics`, two `mtu-pmtud`, one `qos-enterprise`, and
one `urpf`. `debug-dmvpn-phase1` was not among the failures. Direct footer and
deprecated-warning checks passed for target hub and spokes1/2/3. The global
nonzero result is therefore recorded as an unrelated repository baseline, not
a target failure.

## Read-only reviewer closure

The required same read-only reviewer returned **APPROVE — no actionable
findings**. No implementation response or follow-up correction was required.
The reviewer confirmed:

- staged/collapsed Guided Debug pedagogy and unanswered transfer challenges;
- the single causal leaf and native VyOS ownership;
- disclosed startup normalization, live-only repair, and saved-incident
  invariants;
- transactional rollback and capture cleanup;
- honest separation of seven rejected engineering deployments from two
  accepted clean deployment/destroy lifecycles;
- negative, resource, and gate evidence, including the unrelated footer
  baseline;
- `labs/AUTHORING.md` fallback use with no tutor-validation claim; and
- limited scope with `.claude/worktrees/` untouched.

The reviewer independently passed Bash parsing, ShellCheck at warning
severity, Markdown spacing, documentation admonitions, lab lint across 143
labs and 53 images, and `git diff --check`. The review environment contained
no target runtime or generated ContainerLab directory.

## Validation limits

Live validation covered only the environment and duration actually observed.
It does not establish arm64 or physical
appliance behavior, other VyOS releases, encryption, dual-hub failover, large
spoke counts, long-duration stability, WAN loss/reordering, or upgrade paths.
