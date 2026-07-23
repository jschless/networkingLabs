# Feature Probe Record — `internet-peering-ixp`

## Scope and decision

- **Feature and learning objective:** Route-server next-hop/AS-path semantics,
  local RTR validation, deterministic IRR-derived policy, and scoped RTBH.
- **Decision:** documented fallback — FRR 8.4 route servers/participants.
- **Reason and fidelity statement:** cEOS 4.35.2F rejected both
  `neighbor ... route-server-client` and `neighbor ... graceful-shutdown`.
  FRR 8.4 accepted route-server-client and preserved the participant next hop;
  therefore this is a live FRR IXP routing-policy lab, not an EOS operation lab.
- **Owner and date:** WP-07, 2026-07-23.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Linux 5.15.0-181-generic |
| ContainerLab/Docker | 0.74.1 / 29.5.3 |
| FRR image | `frr-lab:local`, ID `sha256:39ea06642b8cfcfaf568a9190fe17b129c55dbce5aa12274526237208b7c3c06`; base `quay.io/frrouting/frr:8.4.2` |
| cEOS image | `ceos:4.35.2F`, ID `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca` |
| Host memory before probe | 15 GiB total, 11 GiB available; 2 GiB swap free |

## Smallest load-bearing test

The disposable two-node cEOS ContainerLab probe deployed in 34.92 seconds
(ContainerLab maximum RSS 41,092 KiB). Both tested EOS commands returned
`% Invalid input`: `neighbor 198.18.70.11 route-server-client` and
`neighbor 198.18.70.11 graceful-shutdown`. Container memory at the sample was
906.7 MiB and 1.438 GiB, exceeding the package target for this role mix.

The FRR initial direct-Docker attempt was intentionally discarded: its daemons
were not mounted and `bgpd` was not running. The definitive probe used the
normal ContainerLab mount pattern. `route-server-client` produced a route at a
client with next hop `198.18.70.12` and AS path `65002`, not the server AS.

FRR's RPKI probe first failed because this image has no standalone `rpkid`.
`/usr/lib/frr/modules/bgpd_rpki.so` is available, and setting
`bgpd_options="  -A 127.0.0.1 -M rpki"` loaded the supported module. The local
RTR cache then showed `connected` and two ROAs. `bgpq4` is absent on the host,
so `generate-filters.sh` is an honest deterministic local substitute; it parses
only checked-in synthetic objects and makes no public-IRR claim.

## Cleanup and repeatability

- Scoped command: `containerlab destroy -t labs/internet-peering-ixp/topology.clab.yml --cleanup`.
- Probe cEOS and direct-Docker resources were destroyed immediately.
- The lab was destroyed and redeployed during the RPKI module correction; the
  second deployment again reached the RTR cache and all containers were scoped
  to `clab-internet-peering-ixp-*`.

## Unsupported behavior and fallback

- cEOS route-server client and graceful-shutdown-neighbor syntax were not
  available on the exact local image. EOS-specific operational semantics are not
  claimed.
- Public IRR, PeeringDB, LOA, NOC data, full-table scale, and physical
  cross-connect/traffic-ratio behavior are evidence/design exercises only.
