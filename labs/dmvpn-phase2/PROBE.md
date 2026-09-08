# dmvpn-phase2 — Pre-implementation Probe

## Scope and method

This record captures the read-only curriculum analysis and main-agent live
probes that selected the remediation design. Post-edit evidence belongs in
`VALIDATION.md`. The lab tutor was unavailable, so `labs/AUTHORING.md` is the
fallback authoring contract; this remediation does not claim tutor validation.

## Classification and platform ownership

- Classification: **Reference/Observation**. The topology exists to expose a
  current-image compatibility boundary, not to ask learners to construct a
  mechanism that the image cannot honestly demonstrate.
- Required prerequisite: `dmvpn-phase1`; `bgp-basics` is also required because
  the observation depends on distinguishing BGP RIB next hops from recursive
  FIB resolution.
- Critical roles: `hub`, `spoke1`, `spoke2`, and `spoke3`, all native
  `vyos:local` routers.
- Incidental role: `br-wan`, an `ops-lab:local` Layer 2 bridge and bounded
  capture point. No critical-role FRR/Linux exception applies.

The original lab exposed a transcription exercise, retained contradictory and
unbound VyOS/FRR/EOS artifacts, used FRR only to bridge Ethernet, had eight
broad checker assertions including a false-positive-prone ping helper, and
claimed that NHRP redirect/shortcut behavior was classic DMVPN Phase 2.

## Current-image tunnel and OSPF probes

Validation used the local VyOS rolling image already selected for the DMVPN
family. VyOS startup migration changed NHRP tunnel addresses to `/32`, and a
live candidate with a `/24` on an NHRP-used tunnel was rejected with:

```text
Tunnel is used for NHRP, Netmask should be /32!
```

All spokes were changed to `/32`, given an exact NHS definition, and registered
successfully. VyOS startup normalization removed the redundant explicit static
hub `map` leaf from each spoke and added `registration-no-unique`; the runtime
still contained the exact `nhs` hub row, and exact hub registration
cardinality/correlation remained the identity contract. Broadcast OSPF hellos
were visible bidirectionally over GRE, with the hub at priority 10 and spokes
at priority 0, but FRR classified the tunnel interfaces as unnumbered and
formed zero neighbors. The original broadcast-OSPF Phase 2 model is therefore
not executable on the current accepted image.

## Preserved-next-hop BGP probe

The live replacement used iBGP AS 65000 with the hub as route reflector. Each
spoke advertised its native dummy service /24 and had the platform-required
bootstrap overlay route through the NHS at distance 250. Explicit neighbor
IPv4-unicast activation was required.

The hub established three peers. Every spoke learned exactly two remote
service /24s, and the BGP RIB preserved the owning remote spoke's overlay
address—for example, spoke1 learned `192.168.2.0/24` through
`172.16.0.12`. Before peer optimization, the kernel FIB recursively resolved
that traffic through the bootstrap route via hub `172.16.0.1`.

## Classic Phase 2 resolution probe

The main probe removed hub `redirect` and spoke `shortcut`, then tested the
preserved BGP next hop. It also tested an on-link tunnel `/24` route and a live
kernel `/24`. Ordinary spoke resolution still did not occur. Adding spoke
`shortcut` alone also did not create a direct mapping. The current `/32` model
therefore did not demonstrate classic Phase 2 ordinary next-hop NHRP
resolution despite the correct BGP next-hop property.

Official current VyOS/FRR semantics represented by the live behavior create
spoke shortcuts in response to hub Traffic Indications: hub `redirect` plus
spoke `shortcut`. That mechanism is the optimization normally associated with
DMVPN Phase 3. It may be studied honestly, but must never be relabeled as proof
of classic Phase 2.

## Accepted reference design

The selected preconfigured reference uses:

- `/32` native VyOS mGRE tunnel addresses, the platform-normalized
  `registration-no-unique` leaf, and exact NHRP registration cardinality and
  tunnel/NBMA correlation;
- native dummy service /24s;
- iBGP AS 65000 with the hub as route reflector, preserving remote-spoke BGP
  next hops;
- one bootstrap overlay route through the hub on each spoke;
- hub NHRP redirect and spoke shortcut; and
- an incidental bound `ops-lab:local` bridge for deterministic packet proof.

The teaching sequence compares the BGP RIB with the initial recursive FIB,
seeds Traffic-Indication shortcuts, proves direct outer GRE bridge-wide, then
perturbs one live resolved service-host map while keeping registration, BGP,
and unrelated paths healthy.

The fault probe also established the correct resolution boundary. Poisoning
remote overlay `172.16.0.12` after seeding did not interrupt service because
an already resolved direct FIB remained usable. Replacing service host
`192.168.2.1` with static unused NBMA `10.0.0.254` did fail spoke1-to-spoke2
while spoke1-to-spoke3, spoke2-to-spoke3, BGP, and hub registration stayed
healthy. The broader `192.168.2.0/24` shortcut sometimes remained visible for
more than 50 seconds; it did not override the more-specific wrong host
resolution and is therefore not a causal fault postcondition. Removing the
live service-host map allowed deterministic reseeding.

Deleting only the tagged service-host leaf left an empty live
`set protocols nhrp tunnel tun0 map` structural command. The accepted minimal
repair therefore deletes the entire live `map` parent—healthy source contains
no configured map—before reseeding, restoring exact live/saved parity.

Normal repair exposed a second operational-state nuance. After reset, spoke3
had the correct dynamic `.12 → 10.0.0.12` overlay row, no
`192.168.2.1` service-host row, and no `192.168.2.0/24` shortcut row, while its
FIB resolved service traffic `via 172.16.0.12 dev tun0` and direct traffic
passed. This proves service-host and prefix-shortcut rows are optional transient
diagnostics; the stable healthy invariant is the correlated remote overlay map
plus direct FIB and traffic. When optional rows appear, their tunnel/NBMA or
prefix/overlay correlations must still be exact, and unexpected rows fail the
checker.

The central seeder bounded-clears transient shortcut and cache state on all
three spokes before each convergence loop, then allows 30 one-second attempts
for all six remote overlay/direct-FIB relationships. The operation never enters
configure mode or writes live/saved configuration. Static fault maps are
configuration, not dynamic cache entries, so the deliberate wrong host map
remains available for the causal negative and must still be live-validated.

An interrupted early fault run also exposed signal-handling risk while the
parent shell waited on a long child checker. The lifecycle now launches long
checker/injection commands in their own interruptible process groups, stops
that group before rollback, ignores subsequent INT/TERM during bounded
rollback, and bounds restore, reseed, and final-check operations. Forced-TERM
recovery remains a required post-edit live revalidation item.

## Risks carried into final validation

Fresh post-edit validation must still complete exact checker totals, normal and
forced-interruption repair, checker atomic negatives, helper idempotence,
active resources, clean destroy, all repository gates, and independent
same-reviewer closure.

The probe did not validate arm64, physical appliances, long-duration
operation, dual hubs, scale, adverse WAN conditions, or a future VyOS/FRR
release that may restore classic shared-subnet Phase 2 behavior.
