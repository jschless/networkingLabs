# Feature Probe Record — `debug-vxlan-evpn`

## Scope and decision

- **Feature and learning objective:** preserve a VXLAN/EVPN forwarding
  incident in which OSPF and EVPN sessions remain healthy while the learner
  correlates the advertised forwarding identity, native VXLAN source, and
  UDP/4789 behavior.
- **Decision:** **Go with native cEOS 4.35.2F for the spine and both VTEPs.**
  Keep `ops-lab:local` Linux only for the two incidental endpoints.
- **Reason and fidelity statement:** the previous all-FRR topology reproduced
  the tunnel-source mechanism only after unrelated underlay, route-reflector,
  and checker defects were repaired at runtime. Native EOS provides the
  platform commands and control/data-plane separation required by the
  objective without retaining those defects.
- **Owner and date:** main Codex agent, 2026-08-06.

This record preserves the previous FRR migration evidence and the native
target-platform probe that authorized the rebuild. Full repeatability,
checker, resource, and final-cleanup evidence is in `VALIDATION.md`.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Ubuntu 22.04, `5.15.0-181-generic`, x86_64 |
| ContainerLab version | `0.74.1`, commit `1866b3a2b` |
| Docker version | client/server `29.5.3` |
| Legacy image | `frr-lab:local`, image ID `sha256:39ea06642b8cfcfaf568a9190fe17b129c55dbce5aa12274526237208b7c3c06`, amd64 |
| Runtime FRR | `FRRouting 8.4_git`; the mounted configurations declared FRR 8.5 |
| Target network image | Licensed local `ceos:4.35.2F`, image ID `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca`, amd64 |
| Target incidental image | `ops-lab:local`, image ID `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`, amd64 |
| Host memory/disk before probe | Not separately recorded; no value is inferred here |

## Smallest load-bearing test

### Legacy migration boundary

The previous five-node lab was deployed without modification:

```text
./scripts/lab.sh deploy debug-vxlan-evpn

spine, vtep1, vtep2, host1, host2: running on frr-lab:local
vtep1/vtep2 OSPF uplink neighbors: Full after convergence
vtep1/vtep2 EVPN peers: Active
host1 -> 172.16.0.2: 100% packet loss
```

The initial state contained three defects unrelated to the intended lesson:

- VTEP and spine loopbacks were passive but not enabled in OSPF, so the
  underlay lacked loopback routes and the iBGP EVPN sessions stayed Active.
- The spine's VTEP peers were not configured as route-reflector clients under
  the `l2vpn evpn` address family, so established sessions did not reflect
  the VTEP EVPN routes.
- The checker searched for the literal word `Established`; FRR's established
  summary rows used a numeric `State/PfxRcd` value instead.

The main agent enabled OSPF on the loopbacks and added the two
route-reflector-client statements under the EVPN address family. With those
incidental defects corrected, the intended fault was isolated:

```text
vtep1 VXLAN local identity: 10.0.0.1
vtep2 VXLAN local identity: 10.0.0.1
remote Type-2/Type-3 forwarding identity: duplicated 10.0.0.1
host1 -> host2: 100% packet loss
```

Recreating only the `vtep2` Linux VXLAN interface with local `10.0.0.2`, then
clearing EVPN, changed its Type-2 and Type-3 next hops to `10.0.0.2` and
restored a five-packet endpoint ping (`5/5`). This proved that forwarding
identity correlation was a viable learning objective, while also proving the
old topology was not a clean Guided Debug baseline.

The probe elapsed time was not separately captured. The no-stream memory
snapshot was:

| Container | Memory |
|---|---:|
| spine | 22.46 MiB |
| vtep1 | 20.82 MiB |
| vtep2 | 20.91 MiB |
| host1 | 19.12 MiB |
| host2 | 19.10 MiB |

The sampled total was approximately 102.4 MiB.

### Native target-platform test

The target probe used the final load-bearing shape: native cEOS roles
`spine`, `vtep1`, and `vtep2`, plus incidental Linux `host1` and `host2`.
EOS 4.35.2F accepted and activated the required native syntax for interface
OSPF, passive loopbacks, an iBGP EVPN route-reflector peer group, per-VLAN
EVPN RD/route targets, and `Vxlan1` source/VLAN-to-VNI mapping.

```text
topology: 3 x ceos:4.35.2F + 2 x ops-lab:local
spine OSPF neighbors: 2 Full
vtep1/vtep2 OSPF neighbors: 1 Full each
VTEP Loopback0 reachability: bidirectional
spine EVPN peers: 2 Established
vtep1/vtep2 EVPN peers: 1 Established each
solved VNI 100: remote IMET, Type-2 MAC, and VTEP state installed
host1 <-> host2: bidirectional forwarding succeeded
```

The fault-boundary probe changed only native `vtep2` tunnel identity:
`Vxlan1` used unadvertised `Loopback100` (`10.0.0.22`) while the BGP router
ID and update source remained Loopback0 (`10.0.0.2`). The EVPN sessions and
documented Loopback0 reachability stayed healthy. The spine received
`vtep2` EVPN advertisements with forwarding identity `10.0.0.22`, but
`vtep1` had no route to that address and did not install the remote IMET,
Type-2, or VTEP state.

A bounded capture during a failed endpoint probe observed one-way UDP/4789
traffic from `10.0.0.22` to `10.0.0.1` carrying VNI 100; both endpoint ping
directions failed. Restoring `Vxlan1` to Loopback0 removed the alternate
loopback, changed the reflected/installed identity back to `10.0.0.2`, and
recovered the remote EVPN state and bidirectional endpoint forwarding.

This native probe passed and authorized the cEOS rebuild. The repeated
fault/repair runs, exact checker counts, native resource snapshot, and final
destroy evidence are recorded once in `VALIDATION.md`.

## Cleanup and repeatability

- **Destroy/cleanup command:** `./scripts/lab.sh destroy debug-vxlan-evpn`.
- **Artifacts checked:** the five exact lab containers and the
  `clab-debug-vxlan-evpn` Docker network.
- **Result:** the previous topology destroyed cleanly with no lab container or
  network left behind.
- **Second old-topology run:** not performed. Repeatability was instead tested
  on the replacement topology and is recorded in `VALIDATION.md`.

## Unsupported behavior and fallback

The legacy Linux VXLAN result is migration rationale only; the native probe
separately validated cEOS syntax, route installation/rejection, VTEP state,
and bounded UDP/4789 behavior. No FRR exception or Linux VTEP fallback is
retained for the critical network roles. The probe does not establish arm64,
physical-ASIC, production-scale, IPv6 VXLAN, or EVPN-multihoming support.
