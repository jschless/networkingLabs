# debug-dmvpn-phase1 — Pre-implementation Probe

## Scope and method

This record separates read-only source analysis and the main agent's
exploratory current-image probe from final-code validation. Post-edit runtime
evidence belongs in `VALIDATION.md`. The lab tutor was unavailable, so
`labs/AUTHORING.md` is the fallback authoring contract; no tutor validation is
claimed.

## Read-only analyst findings

The original lab was correctly aimed at troubleshooting but did not satisfy a
durable Guided Debug contract:

- four native VyOS roles shared an FRR image used only as an Ethernet bridge;
- live VyOS `config.boot` files coexisted with stale, unbound FRR/cEOS
  `daemons`, `frr.conf`, `vtysh.conf`, `setup.sh`, and `startup-config`
  artifacts;
- the saved fault changed three related NHRP leaves, so the incident was not
  atomic; the separate spoke `registration-no-unique` leaf later proved to be
  current-image startup normalization rather than a fault;
- the hub contained redirect and remote-service advertisement pollution that
  contradicted Phase 1 role ownership;
- service addresses were placed on loopbacks rather than the native dummy
  interface model used by the validated sibling lab;
- the checker graded only broad broken-state symptoms and could accept wrong
  images, extra nodes/configuration/routes, partial protocol state, and
  forwarding bypasses; and
- the README disclosed the fault domain and target before learners gathered
  evidence, then offered a broad saved repair.

The analyst recommended retaining the lab as **Guided Debug**, rebuilding it
on the validated `dmvpn-phase1` native-VyOS model, keeping only an incidental
`ops-lab:local` bridge, and selecting a stable one-leaf fault whose symptoms
require real control-plane/data-plane separation.

## Classification and platform ownership

- Classification: **Guided Debug**. Learners receive a complete saved network
  with one intentional fault, isolate it through staged evidence, and apply a
  minimal live-only repair.
- Critical roles: `hub`, `spoke1`, `spoke2`, and `spoke3`, all native
  `vyos:local`. Native VyOS/FRR owns mGRE, NHRP, OSPF, route installation, and
  the repair mechanism.
- Incidental role: `br-wan` on `ops-lab:local`. It provides only exact Ethernet
  bridging and bounded packet observation.
- Prerequisites: `gre-basics` for underlay/overlay reasoning and
  `dmvpn-phase1` for the native Phase 1 control and forwarding model.

## Main current-image design probe

The main agent deployed the original topology and tested candidate one-leaf
faults against the current local VyOS image before any final implementation
was accepted. The probe first established the sibling Phase 1 model: `/32`
mGRE tunnels, one hub, three NHRP spokes, point-to-multipoint OSPF, and native
dummy `/24` service interfaces.

Changing only spoke1's NHS NBMA value was rejected. With its correct static
unicast map still present, that candidate did not produce the intended
forwarding failure and was therefore not a causal teaching fault.

The accepted candidate changed only spoke1's static map for hub overlay
`172.16.0.1` from the correct hub NBMA address to unused `10.0.0.254`, while
leaving its NHS NBMA and multicast target at `10.0.0.1`. In that exploratory
state:

- spoke1 retained underlay reachability;
- the hub retained spoke1's dynamic NHRP registration;
- OSPF hello exchange still exposed the affected peer;
- spoke1 overlay and source-specific service traffic failed; and
- spokes2 and 3 remained healthy with each other.

Correcting only the live static map to `10.0.0.1` restored overlay and service
traffic. The probe compared the saved configuration fingerprint before and
after that live correction and observed it unchanged. This stable
registration-green/unicast-red split was selected because it cannot be solved
by checking only NHRP registration or OSPF peer presence. The deterministic
final-code adjacency and route boundary was measured later in the eighth
cycle below.

The old target and exploratory probe both included explicit
`registration-no-unique` on every spoke. The first implementation deployment
omitted that leaf; current-image migration added it and removed every static
map, erasing the incident. A second implementation deployment stated the
normalized leaf explicitly on all spokes, but migration still removed every
map. At approximately 55 seconds, spoke1 had no live map and forwarded
service traffic normally. Both deployments were rejected and cleanly
destroyed.

A third implementation deployment exercised the bounded topology exec
normalizers. Each reached base live/saved readiness, but all five native map
attempts failed. Main's manual `/bin/vbash -x` isolated the cause: the shared
mutator enabled `errexit` before sourcing the VyOS script template, whose
benign nonzero setup return aborted the helper before `configure`. ContainerLab
logged `rc=1` for each spoke exec but returned deployment status 0; no exact
marker existed and no live or saved map was present. The cycle was rejected
and cleanly destroyed. That iteration moved strict mode immediately after the
template source. Because topology exec failure is not propagated by this
ContainerLab version, exact state/check marker grading remains an essential
deployment acceptance guard.

A fourth implementation deployment exposed one more template interaction.
After sourcing the VyOS template, `set` is an alias for the VyOS configuration
command. The strict-mode line therefore invoked `vyatta_cfg_run set -euo
pipefail` instead of Bash's option builtin, disturbed positional-argument
handling, emitted helper usage, and exited 127. All three normalizers again
returned `rc=1` to ContainerLab with no maps or readiness markers; the cycle
was rejected and cleanly destroyed. The fourth-iteration fix used explicit
`builtin set -euo pipefail` to bypass the alias, before later evidence showed
that strict mode itself was incompatible with native aliases.

A fifth deployment proved that explicit `builtin set` was necessary but not
sufficient. The template had already clobbered `$1` and `$2`; tracing showed
strict mode enabled successfully, followed by an empty `${1:-}`, helper usage,
and exit 127. All maps and markers were again absent. The deployment was
rejected and cleanly destroyed. The fifth-iteration ordering validated and
copied the target/persistence arguments before sourcing, performed every `$#`
check, then sourced the template and referenced only saved variables. Later
evidence removed strict mode but retained that argument ordering.

A sixth deployment reached native configuration mode with correct arguments
and strict handling, but `delete ... || true` still aborted the vbash helper
when migration had removed the map. The native command printed `Nothing to
delete` and returned status 1 before the following `set`; maps and markers
remained absent. The cycle was rejected and cleanly destroyed.

Main then manually proved the safe exact operation: omit `delete` and issue
only the scalar `set ... nbma "$target"`. With no map it added, committed, and
saved the intended leaf successfully. With an existing `.254` map, a
live-only `set` to `.1` atomically replaced that scalar while the saved map
remained `.254`. The shared mutator now uses that single native `set`, with
startup save controlled solely by `--save`.

A seventh deployment reached `vyatta_cfg_run set protocols ...` with the
correct scalar command, then exited status 1 without creating a map. The
filtered vbash trace established that valid VyOS configuration aliases can
return benign nonzero statuses and therefore remain incompatible with shell
`errexit` even after template setup and argument preservation. The deployment
was rejected and cleanly destroyed.

Main's manually proven stdin-native script used the repository's accepted
VyOS helper pattern with no strict shell mode and successfully added/saved an
absent map and replaced an existing map live-only. The inner `set-map.sh` now
uses that exact pattern: pre-source explicit argument validation/copy, source,
`configure`, scalar `set`, `commit`, optional startup `save`, and `exit`.
Failure detection remains strict in the external startup normalizer and exact
state/lifecycle postcondition checks.

## Eighth-cycle accepted behavior discovery

The eighth final-code deployment became the first accepted complete lifecycle,
distinct from the seven rejected engineering deployments above. Its startup
normalization succeeded on all three spokes:
each intended map was exact in live and saved state and every exact readiness
marker was present.

The fresh incident established the deterministic protocol boundary:

- hub NHRP had exactly its local row plus three correlated dynamic spoke rows;
  spoke1 had the exact static hub map to `.254`;
- the hub had three OSPF rows: spoke1 `ExStart/DROther`, spokes2/3
  `Full/DROther`; spoke1 had exactly one hub row in `ExStart/DROther`;
- the hub learned only spoke2/3 service and overlay routes, not spoke1's;
- spoke1 learned no remote service or overlay OSPF route;
- spokes2/3 learned only each other's remote service and overlay route through
  the hub;
- all underlay and NHRP checks and the spoke2↔spoke3 service paths remained
  healthy, while spoke1 overlay/service paths failed.

This refines the mechanism: multicast hellos reach the peer, but the unicast
database exchange follows the bad static resolution and stalls in ExStart.
The same cycle showed legitimate current-image kernel host routes without a
`/32` suffix, including exact `nhid N ... proto nhrp metric 20` rows and OSPF
overlay host routes ending in mandatory `proto ospf metric 20 onlink`.
Pollution checks now allow only the known destination, numeric `nhid`,
correlated next hop, `tun0`, protocol, metric, and protocol-specific `onlink`
shape; they do not blanket-allow NHRP or OSPF routes.

These are accepted current-image behavior observations from the eighth cycle.
The later checker, repair/recovery, full capture, resource, and clean-destroy
results are recorded below and in `VALIDATION.md`.

## Live re-arm convergence probe

The first normal `break.sh` re-arm from exact health changed only spoke1's
live map to `.254`, but the already-Full OSPF adjacency remained cached. The
exact incident predicate therefore could not converge within its 50-second
loop. Main interrupted the rejected attempt with `Ctrl-C`; the existing
transactional trap restored exact health, the outer healthy checker returned
**136/0**, and `break.sh` preserved signal exit status 130.

Main then probed the smallest deterministic operational mechanism. After the
same one-leaf live map mutation, it cleared only spoke1's ephemeral OSPF
process with bounded native FRR `clear ip ospf process`. Twelve seconds later,
spoke1 and hub were exact `ExStart/DROther`, spokes2/3 remained
`Full/DROther`, NHRP remained exact, and `debug_dmvpn_verify_state incident`
returned 0. This operational reset changes and saves no configuration; it
only removes cached adjacency state so a repeat exercise reproduces the fresh
incident. `break.sh` now performs that bounded spoke1-only reset immediately
after mutation, before any post-mutation test hook. A reset timeout/failure
propagates into transactional rollback.

The corrected normal re-arm subsequently returned `BREAK_RC=0`; the complete
incident predicate returned 0, and the healthy checker produced the same exact
incident boundary, **108 passed / 28 failed**. All four repository source
configuration hashes remained unchanged (observed prefixes: hub `137933`,
spoke1 `035327`, spoke2 `afc9d5`, spoke3 `f629f8`).

## Repair precondition atomic probes

Main exercised six one-at-a-time pollution probes from the exact incident.
Every `repair.sh` invocation returned 1 before mutation and spoke1's target map
remained `10.0.0.254`:

1. extra spoke2 OSPF `interface eth1 passive`;
2. extra spoke2 `dum1 198.18.0.1/32`;
3. spoke2 static `198.51.100.0/24` via `tun0`, confirmed present in the kernel;
4. extra spoke2 management address `198.18.0.2/32` on `eth0`;
5. hub NHRP `redirect` Phase 2 pollution; and
6. saved-only spoke2 `dum0` description `Saved pollution`, with live state
   restored exact before repair.

The saved-only test explicitly reported saved configuration mismatch. Its
spoke2 runtime saved SHA changed from prefix `8b874e` to `861030`, then was
byte-restored from a bounded backup to `8b874e`. VyOS left empty parent nodes
after leaf cleanup in two probes: recovery required deleting the complete
empty OSPF `interface eth1` node and the complete empty `protocols static`
node. Those are platform cleanup observations, not additional faults. After
all cleanup, the exact incident predicate returned 0.

## Transactional rollback probes

With the corrected spoke1 operational reset in place, main exercised every
supported rollback path after the real map mutation and OSPF reset:

- the test-only `ERR` hook returned 1; the trap reported exact-health
  restoration and an independent healthy predicate returned 0;
- the `TERM` pause marker was observed after mutation/reset, the exact break
  PID received `TERM`, the helper exited 143, the trap restored exact health,
  and an independent healthy predicate returned 0; and
- the `INT` pause marker was observed after mutation/reset, a PTY `Ctrl-C`
  produced exit 130, the trap restored exact health, and an independent
  healthy predicate returned 0.

Together with the already recorded normal `break.sh` result 0, these probes
cover successful re-arm plus `ERR`, `TERM`, and `INT` recovery after the real
mutation boundary.

## Capture interruption and active-load probes

Main interrupted a healthy-mode capture while its monitor observed the
lab-local `tcpdump` child running. It sent `INT` to the exact host
`bash ./capture.sh healthy` PID 3094557. The helper exited 130 without output.
Cleanup then found zero `tcpdump` processes in `br-wan`, zero host capture or
`setsid` helpers, and zero `/tmp/debug-dmvpn-phase1.*` files. This is accepted
signal-cleanup evidence for an interrupted capture; the separate accepted
fault and healthy capture runs are recorded below.

Main also ran six simultaneous bidirectional source-specific service pings,
covering both directions of every spoke pair, while collecting six Docker
stats samples. The observed per-node maxima were:

| Node | Maximum sampled memory |
|------|------------------------|
| `br-wan` | 660 KiB |
| `hub` | 263.8 MiB |
| `spoke1` | 267.1 MiB |
| `spoke2` | 268.0 MiB |
| `spoke3` | 264.3 MiB |

The maximum aggregate sampled sum was approximately 1063.8 MiB (1.04 GiB).
All nodes remained `running=true`, `OOMKilled=false`, and `RestartCount=0`.
`br-wan` has no Docker healthcheck. All four VyOS containers reported Docker
health `unhealthy` only because of the documented `atopacct` image boundary;
that status was not treated as learner-state evidence. After load, cleanup
found zero ping or `tcpdump` processes and zero target temporary files. These
six short samples are bounded point-in-time observations, not capacity or
long-duration stability claims.

## Accepted lifecycle probes

After all accepted first-cycle checks and active load, main ran
`containerlab destroy -t topology.clab.yml --cleanup`. It returned 0, removed
all five target containers plus the generated host entries and SSH config,
and left no generated ContainerLab directory, target container, target
network, target temporary file, or helper process. The initial count formatter
printed a blank field when its count was zero; the independent filesystem and
runtime checks established the zero results.

A second clean deploy returned 0 and created every declared link. All three
startup normalizers reported verified live and saved targets: spoke1 `.254`,
spoke2 `.1`, and spoke3 `.1`. The fresh exact incident predicate returned 0.
The corrected standalone fault capture then returned 0 with 19 packets, 15
unanswered ARP request records for `.254`, zero `.254` replies, and the exact
incident protocol and route proof.

The second-cycle repair returned 0. The healthy checker passed **136/0** with
its embedded healthy capture. Saved configuration hashes were unchanged
before and after repair: hub `cf78af5c...`, spoke1 `c1e3fd27...`, spoke2
`5f43fd47...`, and spoke3 `ac985919...`. A separate healthy capture returned
0 with exactly eight packets, both hub-facing GRE legs, and no direct spoke
leg. Main then ran `containerlab destroy -t topology.clab.yml --cleanup`; it
returned 0 and removed all five containers plus the generated host and SSH
entries. The final exact audit reported `TARGET_CONTAINERS=0`,
`TARGET_NETWORKS=0`, no generated ContainerLab directory, and no
`/tmp/debug-dmvpn-phase1.*` files. Its process search returned only the audit
shell's self-match, not an actual target helper or capture child. This
completes the second accepted clean deployment/destroy lifecycle.

Two accepted clean deployment/destroy cycles are therefore complete. They are
separate from the seven rejected, cleanly destroyed engineering deployments
used to refine the implementation.

## Accepted gate probes

Final target gates passed: Bash parsing for every target `.sh` file,
ShellCheck at warning severity, exact YAML parsing with five nodes/four links
and the intended images, Markdown spacing, and `git diff --check`. Repository
documentation admonitions and lab lint also passed; lint covered 143 labs and
53 distinct images. Quiz validation passed 44 quizzes and its regression suite
passed seven cases. The enterprise coverage positive/negative fixture contract
passed with 29 topics, three fixture topics, and the expected negative-fixture
failures. `mkdocs build --strict` returned 0 in 28.88 seconds with only the
existing Material 2.0 banner and known non-navigation pages.

Repository-wide `validate-vyos-configs.sh` returned 1 only for the unrelated
existing footer baseline: six `black-core`, two `gre-ipsec`, two
`ipsec-basics`, two `mtu-pmtud`, one `qos-enterprise`, and one `urpf` lab.
`debug-dmvpn-phase1` was not a failure. Direct target footer and deprecated-
warning checks passed for hub and spokes1/2/3, so the repository-wide result
is recorded as unrelated baseline rather than a target failure.

The accepted source keeps uniform `registration-no-unique` because that is
the current-image normalized spoke model, but does not claim it preserves a
map. Instead, each spoke runs a bounded native post-migration helper after a
successful live/saved config readiness probe. The helper applies that spoke's
intended map, commits and saves it, and returns only after exact live and
`/config/config.boot` map verification. A timeout/failure returns nonzero and
is logged by ContainerLab; because the current ContainerLab process does not
propagate that status, the exact per-spoke marker prevents state/check
acceptance. Runtime break and repair call the shared map mutator without the
startup-only save flag, so their learner lifecycle remains strictly live-only.

## Accepted implementation contract

The remediated source is designed to enforce:

- exactly five nodes and four links, with native VyOS on all learned roles;
- complete healthy state except one saved spoke1 map leaf;
- exact live and saved learner-owned interface/protocol definitions;
- independently derived ContainerLab management interface and route state;
- exact address, route, bridge, NHRP, OSPF, and service-path inventories;
- no redirect, shortcut, fixed tunnel remote, static/dynamic route bypass,
  stale passive `eth1`, or hub-owned service LAN; uniform current-image
  `registration-no-unique` and the exact startup-normalization readiness
  marker are required on the spokes;
- live-only, idempotent repair with pollution rejection and unchanged saved
  startup state;
- transactional re-arming with normal-error and signal rollback after real
  mutation; and
- bounded incident ARP evidence plus healthy bridge-wide Phase 1 GRE evidence
  with exact child cleanup.

## Read-only reviewer closure

The required same read-only reviewer returned **APPROVE — no actionable
findings**. The reviewer confirmed:

- staged/collapsed Guided Debug pedagogy and unanswered transfer challenges;
- one causal learner-owned leaf and native VyOS ownership;
- disclosed startup normalization, live-only repair, and saved-incident
  invariants;
- transactional rollback and exact capture cleanup;
- honest separation of seven rejected engineering deployments from two
  accepted clean deployment/destroy lifecycles;
- focused negatives, resource evidence, completed gates, and the unrelated
  repository-wide footer baseline;
- the `labs/AUTHORING.md` fallback without a tutor-validation claim; and
- bounded scope with `.claude/worktrees/` untouched.

The reviewer independently passed Bash parsing, ShellCheck at warning
severity, Markdown spacing, documentation admonitions, lab lint across 143
labs/53 images, and `git diff --check`. The reviewer found no runtime or
generated ContainerLab directory.

## Risks carried into final validation

The exploratory and seven rejected deployments alone did not validate the
corrected final topology or lifecycle. The accepted cycles above now cover
normalization, fresh incident and healthy predicates, both accepted capture
modes, transactional interruption, active-load observation, and two clean
deployment/destroy lifecycles plus the target and repository gates above.
Reviewer closure is recorded above. This evidence intentionally makes no
self-referential commit claim; Git history provides the implementation
identity, which the subsequent ledger-only entry records.

The probe did not cover arm64, physical appliances, other VyOS releases,
dual-hub failover, encryption, scale, long-duration operation, or adverse WAN
conditions.
