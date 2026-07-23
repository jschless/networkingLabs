# Validation Record — `enterprise-dual-stack-capstone`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-23, WP-08 worker |
| Host OS/kernel | Linux 5.15.0-181-generic x86_64 |
| ContainerLab/Docker versions | 0.74.1 / 29.5.3 |
| Image tags/digests | `ceos:4.35.2F` (`f27a0e7dba17`), `quay.io/frrouting/frr:10.5.0`; local tools image built from `debian:12.12-slim` |
| Repository commit | recorded after final commit |

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Feature probe deploy | `containerlab deploy -t /tmp/enterprise-dual-stack-probe/topology.clab.yml --reconfigure`; two cEOS reachable | ~37 s | 2.54 GiB steady |
| Feature probe checks | IPv4 OSPF, OSPF3 agent, IPv6 ND/DAD observation passed | < 1 min | 2.54 GiB steady |
| Full topology deploy | ten nodes created cleanly; cEOS/endpoint convergence was not green after OSPFv3 syntax correction | ~36 s to containers running | ~3.8 GiB cEOS steady plus Linux nodes |
| Break-It | not run: baseline check was not green | not applicable | not applicable |
| Minimal repair | not run: baseline check was not green | not applicable | not applicable |
| Destroy/cleanup | probe `containerlab destroy --cleanup`; no probe containers | ~2 s | 0 GiB residual |
| Redeploy/recheck/destroy | full redeploy reproduced the unresolved baseline convergence failure; scoped destroy completed | ~36 s / ~2 s | 0 GiB residual |

## Positive and negative evidence

The smallest load-bearing probe positively formed OSPF/OSPFv3 control-plane state
and exposed live IPv6 ND/DAD mechanics. It negatively demonstrated unavailable cEOS
RA guard, DHCPv6 guard, ND inspection, and unproven IPv6 VRRP in this container
image. The full topology created all ten containers but did not converge to a green
baseline: `show ipv6 ospf neighbor` reported OSPF3 inactive and corp-to-app/DNS
checks failed after the corrected startup syntax was applied. This package is not a
completed level-4 validation; the next owner must resolve that startup/convergence
regression, then run the unexecuted Break-It/repair/redeploy sequence.

## Repository gates

Run before PR: `python3 scripts/lint-labs.py`, `./scripts/check-docs-admonitions.sh`,
`mkdocs build --strict`, and `shellcheck -S warning scripts/*.sh labs/*/check.sh`.

## Limitations, refresh, and cleanup

- **Unsupported/evidence-only:** cEOS ASIC RA/DHCPv6 guard and ND inspection;
  cEOS IPv6 VRRP; Jool NAT64/DNS64; shared-L2 relay and live dynamic DNS updates.
- **Image refresh:** Debian 12.12 base, FRR 10.5.0 and cEOS 4.35.2F must be reviewed
  under `docs/image-policy.md` before release; no vulnerability certification is made.
- **Residual artifacts:** probe containers were absent after scoped destroy.
- **Follow-ups not represented as complete:** PMTUD payload-loss injection, source-view
  BIND policy, and full two-prefix RA deployment require a subsequent validated run.
