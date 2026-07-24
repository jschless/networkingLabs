# Validation Record — `enterprise-dual-stack-capstone`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-23, WP-08 worker |
| Host OS/kernel | Linux 5.15.0-181-generic x86_64 |
| ContainerLab/Docker versions | 0.74.1 / 29.5.3 |
| Image tags/digests | `ceos:4.35.2F` (`f27a0e7dba17`), `quay.io/frrouting/frr:10.5.0`; local tools image built from `debian:12.12-slim` |
| Repository commit | updated with final fix commit |

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Feature probe deploy | `containerlab deploy -t /tmp/enterprise-dual-stack-probe/topology.clab.yml --reconfigure`; two cEOS reachable | ~37 s | 2.54 GiB steady |
| Feature probe checks | IPv4 OSPF, OSPF3 agent, IPv6 ND/DAD observation passed | < 1 min | 2.54 GiB steady |
| Full topology deploy | `containerlab deploy -t labs/enterprise-dual-stack-capstone/topology.clab.yml --reconfigure`; ten containers running, then cEOS readiness converged | ~37 s deploy; ~60 s readiness | ~3.7 GiB cEOS plus <0.1 GiB Linux |
| Healthy/check | `./scripts/lab.sh check enterprise-dual-stack-capstone`: 18 passed, 0 failed | <10 s | ~3.8 GiB total observed |
| Break-It | `break-it.sh`, then normal check: IPv6 ping and HTTP assertions failed while 16 assertions passed | <10 s | unchanged |
| Minimal repair/check | `repair-break-it.sh`, then normal check: 18 passed, 0 failed | <10 s | unchanged |
| Destroy/cleanup | `containerlab destroy -t labs/enterprise-dual-stack-capstone/topology.clab.yml --cleanup` | ~2 s | 0 GiB residual |
| Redeploy/recheck/destroy | clean reconfigure/deploy and a second 18/0 check completed; final scoped destroy follows this record | ~37 s / ~60 s readiness | same |

## Positive and negative evidence

The smallest load-bearing probe positively formed OSPF/OSPFv3 control-plane state
and exposed live IPv6 ND/DAD mechanics. The clean full run passed OSPFv2/v3,
dual eBGP, aggregate hygiene, A/AAAA/PTR, dual-stack application traffic, guest policy
denials, and IPv4-only behavior. Break-It injected a dist2 IPv6 Null0 return-path
blackhole: IPv4 and control-plane checks stayed healthy while IPv6 ping and HTTP
failed; removing only that route restored all checks. No AAAA record was removed.

## Repository gates

Run before PR: `python3 scripts/lint-labs.py`, `./scripts/check-docs-admonitions.sh`,
`mkdocs build --strict`, and `shellcheck -S warning scripts/*.sh labs/*/check.sh`.

## Limitations, refresh, and cleanup

- **Unsupported/evidence-only:** cEOS ASIC RA/DHCPv6 guard and ND inspection;
  cEOS IPv6 ACL interface attachment and IPv6 VRRP; Jool NAT64/DNS64; shared-L2
  relay and live dynamic DNS updates. Guest IPv6 enforcement is the labeled Linux
  nftables fallback.
- **Image refresh:** Debian 12.12 base, FRR 10.5.0 and cEOS 4.35.2F must be reviewed
  under `docs/image-policy.md` before release; no vulnerability certification is made.
- **Residual artifacts:** probe containers were absent after scoped destroy.
- **Follow-ups not represented as complete:** PMTUD payload-loss injection, source-view
  BIND policy, and full two-prefix RA deployment require a subsequent validated run.
