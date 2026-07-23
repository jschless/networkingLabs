# Validation Record — `internet-peering-ixp`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-23, WP-07 |
| Host OS/kernel | Linux 5.15.0-181-generic |
| ContainerLab/Docker | 0.74.1 / 29.5.3 |
| Image | `frr-lab:local` (`sha256:39ea06642b8cfcfaf568a9190fe17b129c55dbce5aa12274526237208b7c3c06`), base `quay.io/frrouting/frr:8.4.2` |
| Repository commit | `851ab15ad014efdc539364b9cee180c18e40805a` plus this worktree changes |

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Deploy | topology deployed with 12 scoped nodes | 3.89 s | deploy process max RSS 40,052 KiB |
| RTR/readiness | local cache connected and two ROAs loaded | <3 s | 206 MiB steady across 12 containers |
| Positive check | baseline sessions, policy, RTR, and content path | passed | — |
| RTBH | selected /32 drops; `.10` service remains reachable | passed | — |
| Break-It | stale prefix absent while sessions remain up | expected failure | — |
| Repair | regenerate/review/apply only the SaaS prefix policy | passed in live walk | — |
| Destroy/redeploy | scoped destroy/redeploy repeated during module probe | passed | — |

## Positive and negative evidence

- All redundant and bilateral sessions established. A route-server path retained
  content next hop `198.18.70.12` and AS path `65002`, not a route-server hop.
- RTR classified content valid, SaaS not-found, and the transit-origin copy
  invalid; policy did not select the invalid path.
- Unregistered/stale routes were denied without session loss; enterprise did not
  transit content to transit. RTBH used only `65010:666` and `.66/32`.

## Repository gates

The required lint, docs-admonition, strict MkDocs, and ShellCheck gates are run
after the final cleanup and recorded with their exact output in the PR.

## Limitations, refresh, and cleanup

- This is live FRR BGP/RTR/Linux forwarding, not public IXP, port, full-table,
  PeeringDB, LOA, NOC, or physical-cross-connect fidelity. See `PROBE.md`.
- Refresh the pinned base image under the image policy and repeat this clean run.
- Scoped `containerlab destroy -t labs/internet-peering-ixp/topology.clab.yml --cleanup`
  leaves no current-lab resources; no runtime state or secrets are committed.
