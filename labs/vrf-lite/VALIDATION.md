# VRF-Lite validation record

This record separates read-only discovery and static implementation checks from
the orchestrator's clean acceptance. `lab-tutor` is unavailable in this
environment and is not claimed.

## Read-only analyst findings

- The lab is a **Build** lab: students create both VRFs, own every PE data
  interface, install tenant routes, prove isolation, and authorize a precise
  cross-VRF share.
- pe1 and pe2 are the only learned roles and must remain native cEOS. The four
  CEs are traffic endpoints, so retaining cEOS there added cost without adding
  a learning mechanism.
- The former six-cEOS deployment consumed approximately **7.235 GiB** during
  exploration. Replacing four incidental roles with `ops-lab:local` preserves
  behavior while materially reducing the footprint.
- The old checker used a generic EOS ping expression where `0%` could match
  `100%`; exact command status and explicit sources are required instead.
- The former README documented an unverified cross-VRF form, placed a
  one-direction leak on both PEs, and included an unchecked OSPF full-config
  experiment. Those claims were removed.

## Native main probe

The orchestrator's read-only/native probe ran on amd64 with:

- image tag `ceos:4.35.2F`;
- EOS build `4.35.2F-46221466.4352F`;
- two independent VRF routing tables and dedicated RED/BLUE inter-PE links.

The probe established these authoritative platform facts:

- ordinary per-VRF static routing works with the intended addressing;
- the working EOS cross-VRF declarations on pe1 are
  `ip route vrf VRF-BLUE 10.10.0.1/32 egress-vrf VRF-RED 10.10.12.1` and
  `ip route vrf VRF-RED 10.20.0.1/32 egress-vrf VRF-BLUE 10.20.12.1`;
- only those two pe1 `/32`s are needed for symmetric ce-a1↔ce-b1 sharing;
  pe2 needs no cross-VRF route;
- route detail exposes `(egress VRF VRF-RED)` and
  `(egress VRF VRF-BLUE)` resolver context;
- three sourced RED pings produce exactly three requests and three replies on
  pe1 Linux interface eth2, while BLUE produces the same bounded count only on
  eth4;
- replacing only the BLUE-to-ce-a1 route with the same declaration minus its
  egress resolver context leaves it saved but inactive, preserves all ordinary
  same-tenant paths, and breaks the approved shared path.

## Static implementation gates — 2026-09-07

The implementation worker performed no topology deployment or mutation. The
main orchestrator ran these source-only checks before live acceptance:

- Bash parser checks for every target shell file;
- ShellCheck at warning severity;
- YAML parsing for the topology;
- repository lab-lint/document checks where available;
- answer-leak and stale-syntax searches;
- whitespace and diff inspection.

The implementation now contains a mixed six-node topology, answer-free PE
startup configs, strict idempotent endpoint scaffolds, a shared exact-state
library, transactional solution/fault/repair helpers, a bounded owned-process
capture helper, and a non-solving exact checker. Solution rollback protects
both running and startup configurations on both PEs before mutation and
includes test-only failure and tracked-hold hooks.

## Main orchestrator acceptance — 2026-09-07

Acceptance used one clean exploratory deployment and one clean acceptance
deployment. A later supported destroy/deploy recovery was required only after
the deliberately unsupported direct-Docker-restart probe described below.

- The answer-free baseline classified exactly and failed the original
  43-assertion checker at **23 passed / 20 failed**. The two subsequently added
  exhaustive denial directions were each independently proven negative; the
  final healthy checker contains **45 assertions**.
- The transactional solution converged from answer-free state, repeated from
  healthy state, and produced **45 passed / 0 failed**. Forced ERR, INT, and
  TERM exits restored both running and startup planes to exact answer-free
  state and left no `vrf-lite.*` backup directory.
- Endpoint-address drift was rejected. Saved-only PE drift produced
  **44 passed / 1 failed**, solely on the saved-plane assertion. An unauthorized
  ce-a2↔ce-b2 share produced **42 passed / 3 failed**: exact running scope and
  both newly exhaustive forwarding denials.
- The fault helper passed forced ERR, INT, and TERM rollback, armed repeatedly,
  and reached **40 passed / 5 failed**. Only pe1 running/saved scope, the
  inactive BLUE route, and the two approved-share directions failed. The
  focused repair restored **45 passed / 0 failed** and removed its backup.
- The capture helper observed exactly three requests and three replies on each
  dedicated RED/BLUE link, with no opposite-tenant addresses. Normal, forced
  ERR, INT, and TERM exits left no tagged process or temporary directory.
- A direct `docker restart` retained `OOMKilled=false` but demonstrated the
  expected Containerlab boundary: injected cEOS data links disappeared and
  Linux post-deploy setup hooks did not rerun. The documentation now directs a
  supported destroy/deploy recreation, which restored the exact answer-free
  scaffold and then reconverged to **45 passed / 0 failed**.
- The supported final deployment reported `OOMKilled=false` and restart count
  zero on all six nodes. A bounded sample measured approximately **1.13 GiB**
  per cEOS PE and **0.64 MiB** per Linux endpoint, about **2.27 GiB** total
  versus the former six-cEOS exploratory footprint of 7.235 GiB.

## Independent review and closure

The read-only reviewer independently reproduced **45 passed / 0 failed** and
the static gates, then requested four changes: hard per-command bounds,
snapshot preservation on failed restore, cleanup after partial snapshot
creation, and a complete pe2 Task 1 solution block. All four were implemented.

Post-review failure injection proved that:

- a forced failure immediately after backup-directory creation returns no path
  and removes the partial directory;
- an intentionally invalid restore file makes restore fail while retaining both
  protected files;
- solution and fault rollback verify the original live state before deleting
  successful snapshots; and
- the final bounded capture still returns the exact tenant-only counts and
  leaves no process or file residue.

The same reviewer then returned **APPROVE** with no remaining findings. The
final destroy completed in two seconds. No target container, Containerlab
inspection entry, data link, SSH fragment, hosts entry, runtime directory,
backup, capture directory, or tagged helper process remained.
