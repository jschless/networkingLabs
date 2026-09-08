# BFD with OSPF validation record

This record separates read-only discovery and source-only implementation from
the orchestrator's clean acceptance. `lab-tutor` is unavailable in this
environment and is not claimed.

## Read-only analyst findings

- The lab is a **Build** lab: students create the complete OSPF process and
  every BFD binding/timer on an answer-free routed triangle, expose the control
  packets, measure failure detection, and diagnose a negotiated-timer fault.
- r1, r2, and r3 are all learned roles. Retaining native cEOS on all three is
  necessary because students inspect EOS OSPF/BFD configuration, negotiated
  detail, routing behavior, and failover on every node.
- The unused FRR daemon, `vtysh`, and per-router `frr.conf` files were unrelated
  to the native topology and have been removed.
- The old checker reported **2 passed / 3 failed** on the answer-free baseline,
  but both ping tests were actually 100% loss. Its `0% packet loss` substring
  test could match `100% packet loss`; the replacement requires the exact
  transmitted/received summary and explicit loopback sources.

## Native main probe

The orchestrator's one native exploratory probe ran on linux/amd64 with:

- image tag `ceos:4.35.2F`;
- EOS build `4.35.2F-46221466.4352F`;
- three native cEOS routers, each with two point-to-point triangle links.

The probe established these authoritative platform facts:

- the working OSPF form is process `router ospf 1`, a loopback-derived
  `router-id`, interface `ip ospf area 0.0.0.0`, and Ethernet
  `ip ospf network point-to-point`;
- OSPF registration uses process-level `bfd default`;
- the working timer form is interface-level
  `bfd interval 300 min-rx 300 multiplier 3`;
- legacy `ip ospf bfd` and nested BFD timer forms are rejected by this EOS
  release;
- every healthy router has exactly two Full point-to-point neighbors, two Up
  BFD peers, and detail showing 300 ms TxInt/RxInt, multiplier 3, 900 ms detect
  time, and `Registered protocols: ospf`;
- r1 learns the r2/r3 loopbacks directly and installs ECMP for the opposite
  10.1.23.0/30 link; all six directed sourced-loopback pings work;
- changing only saved and running r2 Ethernet1 to 3000/3000/3 preserves all
  six neighbor directions, all six BFD peer rows, and reachability, while both
  r1-r2 detail views negotiate 3000/3000/3 with 9000 ms detect time;
- under that slow-timer fault, the tagged carrier-up INPUT drop was detected in
  **8.280 seconds**;
- with canonical BFD, r1 rerouted 10.0.0.2/32 through r3 in **996 ms** after the
  carrier-up INPUT drop; with BFD registration removed on all three routers,
  the identical fault took **43.321 seconds** under OSPF's default
  Hello10/Dead40 behavior;
- a 12-second r1 eth1 observation decoded **91** bidirectional UDP/3784 BFD
  controls and **2** OSPF hellos;
- one resource sample measured approximately **1.124 GiB**, **1.131 GiB**, and
  **1.114 GiB** for r1/r2/r3 (about **3.369 GiB** total). All three reported
  `OOMKilled=false` and restart count zero.

## Static implementation gates — 2026-09-07

The implementation worker performed no topology deployment, destruction,
restart, or container mutation. Source-only validation covers:

- Bash parser checks for every target shell file;
- ShellCheck at warning severity;
- YAML parsing for the topology;
- repository lab-lint and documentation checks where available;
- stale-syntax, answer-leak, secret, and whitespace searches;
- final diff and executable-mode inspection.

The implementation contains answer-free native startup configs, a shared exact
state library, an exact non-solving checker, transactional solution/fault/repair
helpers, bounded owned-process capture, and a protected A/B measurement helper.
Every mutating helper uses hard command bounds. Configuration snapshots clean
up partial creation, cover both running and startup planes, are deleted only
after verified restore, and remain available if restore verification fails.
Test-only failure and tracked-hold hooks support deterministic ERR/INT/TERM
rollback checks during acceptance.

The High Availability quiz and answer key were reviewed. Their description of
protocol-independent asynchronous BFD, echo-mode scope, and virtual scheduling
risk does not conflict with the native findings, so neither file was changed.

## Main orchestrator acceptance — 2026-09-08

One clean Containerlab 0.74.1 deployment was used for acceptance. Live
output-format tuning made three exact parsers match authoritative EOS output:
route legend rows are excluded, the automatic OSPF `max-lsa 12000` declaration
is treated as required platform state, and BFD peer rows are read from the
single-record detail form rather than EOS's split summary table.

- The exact answer-free configuration and interface scaffold passed. All six
  directed connected-link pings worked, remote loopbacks remained unreachable,
  and the healthy checker rejected the baseline at **11/27**.
- `solution.sh` reached **38/0** from answer-free and again from healthy.
  Forced ERR, INT, and TERM paths restored their originating exact state;
  partial-snapshot failure left no backup directories.
- A saved-only OSPF declaration produced exactly **37/1**. The local ping
  parser also rejected a native summary containing `0 received, 100% packet
  loss`; both negatives were removed and the checker returned to **38/0**.
- `break.sh` twice produced the exact intended fault. All six directed BFD
  views and every OSPF neighbor/ping remained healthy, while both r1-r2 detail
  views negotiated 3000 ms Tx/Rx and a 9000 ms detect time. The healthy checker
  rejected that state at **34/4**. `repair.sh` and its idempotent repeat restored
  **38/0**.
- `capture.sh` accepted eight bidirectional UDP/3784 BFD controls and two
  bidirectional OSPFv2 hellos. Normal, forced-ERR, INT, and TERM exits left no
  owned process or host temporary-directory residue.
- A forced measurement failure after rule insertion removed the tagged rule,
  restored all three configuration planes, and left no snapshots. The normal
  A/B run measured **35.217 seconds** with OSPF alone and **1.029 seconds** with
  BFD. Both trials kept r2 Ethernet1 up/up, selected r3 as r1's alternate path,
  removed the rule, and returned to **38/0**.
- Final resource use was 1.135/1.137/1.127 GiB for r1/r2/r3, about 3.399 GiB
  total. Every router reported `OOMKilled=false` and restart count zero.

Final source gates passed after live tuning: Bash parsing, ShellCheck warning
severity, topology YAML parsing, all-lab lint, Markdown spacing, docs
admonitions, quiz/key validation, strict MkDocs build, and `git diff --check`.
The final supported destroy completed in **1.77 seconds**. No target container,
data link, generated lab directory, SSH entry, hosts entry, capture directory,
backup, or tagged-rule residue remained.

## Independent review — 2026-09-08

The same independent read-only reviewer inspected `labs/AUTHORING.md`, every
modified/new lab file, deleted FRR artifacts, answer-free baselines, HA track
documentation, validation claims, and the live healthy state. They independently
confirmed **38/0**, exact neighbor/BFD/route/ping state, platform/resource facts,
transaction retention and rollback, capture ownership, and measurement safety.
Their final verdict was **APPROVE — no actionable findings**. The reviewer made
no file, configuration, or topology changes.
