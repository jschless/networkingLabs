# dmvpn-phase1 — Pre-implementation Probe

## Scope and method

This record captures the read-only analysis and main-agent live probes that
selected the remediation design. Post-edit evidence belongs in
`VALIDATION.md`. The lab tutor was unavailable, so `labs/AUTHORING.md` is the
fallback authoring contract; this remediation does not claim tutor validation.

## Classification and platform ownership

- Classification: **Build**. Learners build the complete NHRP and OSPF
  learned plane on three spokes; the hub is scaffolded.
- Critical roles: `hub`, `spoke1`, `spoke2`, and `spoke3`, all on native
  `vyos:local`. Learners configure and diagnose the native VyOS/FRR NHRP and
  OSPF mechanisms, so no critical-role Linux exception applies.
- Incidental role: `br-wan`, which only bridges four interfaces and supports
  capture. It uses `ops-lab:local` with an idempotent bound setup script.
- Prerequisites: `gre-basics` for overlay/underlay reasoning and
  `ospf-multiarea` for OSPF adjacency and route interpretation.

The original lab mixed active VyOS configuration with unbound FRR and Arista
answer artifacts, used an unnecessary FRR image as an Ethernet bridge,
exposed answer-adjacent configuration, described contradictory tunnel
semantics, and graded only seven broad outcomes. Those stale artifacts are
not part of the remediated topology.

## Baseline probe

On the untouched topology, all four WAN addresses could reach one another.
The hub had no dynamic NHRP registration and no OSPF neighbor; the spokes had
no learned protocols and could not reach the hub tunnel address. Linux
reported all four `tun0` devices as GRE `remote any`, and the bridge carried
exactly its four intended forwarding ports.

The current VyOS operational command `show ip nhrp` was incomplete. Direct
`vtysh -c 'show ip nhrp'` returned the usable table with interface, type,
protocol address, NBMA address, claimed NBMA address, flags, and identity.

## Native NHRP tunnel-semantics probe

The intended old prose called spoke tunnels point-to-point. A live probe added
a fixed GRE remote to spoke1 and then configured native NHRP. On VyOS rolling
release `2026.03.15-0031`, `nhrpd` terminated with `SIGSEGV` in
`nhrp_interface_update_nbma`; VyOS rolled back the NHRP candidate. Native NHRP
on the original mGRE spoke interface committed and converged normally.

The remediated design therefore keeps all spokes honest mGRE interfaces. It
enforces Phase 1 behavior through hub-preserved OSPF next hops, hub-only NHRP
maps, and the absence of redirect/shortcut state. It does not claim that the
spoke interfaces are point-to-point.

## Healthy mechanism probe

The accepted probe state used this exact model:

- hub NHRP: holdtime 300, multicast dynamic, network ID 1; no redirect and no
  shortcut behavior. VyOS startup migration normalizes the NHRP-server
  configuration by adding `registration-no-unique`, so the source now states
  that hub-only platform default explicitly; spokes do not use it, and exact
  table cardinality/correlation still requires three unique registrations;
- each spoke: one NHS/static map from `172.16.0.1` to `10.0.0.1`, multicast
  replication to `10.0.0.1`, holdtime 300, and network ID 1;
- OSPF point-to-multipoint on `tun0`, with each spoke service /24 represented
  by a native VyOS dummy interface.

The hub showed one local NHRP row plus three dynamic `T` registrations. Each
spoke showed one local row and one static hub row. The hub formed exactly
three Full OSPF adjacencies; each spoke formed exactly one, with the hub.
Source-specific traffic passed among all three service addresses.

A bounded, bridge-wide `br-wan` capture of spoke1-to-spoke2 service traffic
showed outer GRE `10.0.0.11 > 10.0.0.1`, followed by
`10.0.0.1 > 10.0.0.12`, with no direct `.11 > .12` outer leg. Capturing on
`any` exposes each packet at both ingress and egress; eight records therefore
represent the two hub-facing legs of one request/reply, observed twice each.

## Deliberate fault probe

Changing only spoke1's live NHRP multicast replication target from
`10.0.0.1` to unused `10.0.0.254` produced a stable partial failure after the
OSPF dead interval:

- the hub retained spoke1's dynamic NHRP registration;
- spoke1 retained WAN and hub-tunnel reachability;
- spoke1 saw the hub in `Init`, while the hub retained only spokes2/3 Full;
- spoke1 lost remote service routes and source-specific service reachability;
- spokes2 and 3 remained healthy with each other; and
- saved spoke1 configuration remained healthy and unchanged.

Restoring only the correct multicast target recovered OSPF and service
traffic. This became the opaque, live-only Break-It lifecycle.

## Risks carried into final validation

Fresh post-edit deployment must still verify output-normalization assumptions,
exact live/saved state, checker atomic negatives, helper idempotence,
transactional interruption recovery, bounded capture cleanup, active-load
resources, repository gates, review closure, and clean destroy. The probe did
not validate arm64, physical appliances, long-duration stability, encryption,
dual-hub failover, scale, or adverse WAN conditions.
