# dmvpn-phase3 — Pre-implementation Probe

## Scope and method

This record separates the main orchestrator's reported live design probe from
post-edit validation. Final implementation evidence belongs in
`VALIDATION.md`. The requested lab-tutor skill was unavailable, so
`labs/AUTHORING.md` is the fallback student-flow contract; no tutor validation
is claimed.

## Classification and role ownership

- Classification: **Build**.
- Prerequisites: `dmvpn-phase1` and the `dmvpn-phase2` compatibility study.
- Critical roles: `hub`, `spoke1`, `spoke2`, and `spoke3`, all native
  `vyos:local` routers.
- Incidental role: `br-wan`, an `ops-lab:local` Layer 2 bridge and bounded
  capture point. No critical-role FRR/Linux exception applies.

The legacy lab mixed unbound VyOS, FRR/Linux, and EOS artifacts; exposed
answers in startup files; graded nine broad assertions; lacked exact saved
state, deterministic transition, direct packet proof, and a transactional
fault; and taught a route-scaling explanation that live behavior disproved.

## Rejected legacy design

The reported main-agent probe first tested the old design on the current local
VyOS image. Three OSPF point-to-multipoint adjacencies formed successfully.
Each spoke also advertised its service LAN into area 0 while the hub
redistributed a static `192.168.0.0/16` summary.

That combination did **not** leave each spoke with only the summary. Remote
spokes learned per-spoke intra-area service specifics as well as the external
`/16`; the legacy loopback probe rendered those specifics as service-host
`/32`s. The hub's `summary-address` aggregated its redistributed external
routes but could not suppress reachability originated by spokes inside the
same area. That evidence is sufficient to disprove the old O(1)/sole-summary
claim. The legacy probe did not independently establish route preference
between those specifics and the final NHRP behavior, so no such preference or
shortcut-masking claim is retained.

## Accepted corrected design

The successful probe kept service ownership at the hub:

- spokes advertised only overlay `172.16.0.11/12/13/32` into OSPF area 0;
- the hub owned exact static service routes `192.168.1/2/3.0/24` through the
  corresponding spoke overlay address;
- the hub redistributed static and applied
  `summary-address 192.168.0.0/16`; and
- the hub sent NHRP redirects while each spoke consumed shortcuts.

After transient NHRP state was cleared, every spoke held exactly one remote
service route—the external `/16` through hub `172.16.0.1`—and no remote
service `/24` or `/32`. Remote overlay `/32`s still arrived through OSPF so the
hub could resolve its exact service statics and peers could resolve redirected
identities. A fresh kernel lookup used the hub as first hop.

All six directional service flows then succeeded. Traffic produced a
correlated remote-overlay NHRP mapping and, on this image, a dynamic
service-host NHRP mapping plus a service-prefix shortcut such as
`dynamic 192.168.2.0/24 172.16.0.12`; `Via` appears in the column header, not
the data row. The resulting host FIB used `tun0` directly toward the remote
overlay. These exact mapping and prefix keys are qualified as current-image
output; a different implementation may expose a host shortcut without
changing the Phase 3 redirect/resolution mechanism.

## Fault probe

The main probe removed spoke1's live `shortcut` leaf, cleared transient state,
and sent spoke1-to-spoke2 service traffic. Reachability survived through the
hub summary. Hub registrations, every OSPF adjacency, and unrelated spoke
traffic stayed healthy, but spoke1 created neither the target service-host
mapping nor the service-prefix shortcut, and its FIB remained through hub
`172.16.0.1`.

Restoring the leaf returned direct optimization. This establishes the fault's
causal boundary: missing shortcut consumption is an optimization failure, not
a connectivity outage. The final helper must keep this change live-only,
preserve the saved configuration hash, restore only the causal leaf on
ERR/INT/TERM, kill active descendants before rollback, reseed transient state,
and require the full checker.

## Final-validation requirements

Fresh post-edit validation must still prove the learner baseline, executable
solution and idempotence, exact checker total, summary-only pre-traffic state,
all six host mappings and service-prefix shortcuts, direct bridge capture,
focused atomic negatives,
normal/idempotent/forced-interruption recovery, active memory, at least two
clean destroys, repository gates, and read-only same-reviewer closure.

The reported probe did not validate the final files, arm64, physical
appliances, hardware offload, IPsec, dual hubs, large scale, long-duration
operation, adverse WAN behavior, or a future VyOS/FRR image.
