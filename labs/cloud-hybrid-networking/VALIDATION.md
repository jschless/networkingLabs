# Validation Record — `cloud-hybrid-networking`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-22 / WP-01 |
| Host OS/kernel | Linux `5.15.0-181-generic` |
| ContainerLab/Docker versions | ContainerLab 0.74.1 (`1866b3a2b`), Docker 29.5.3 |
| Image tags/digests | `ceos:4.35.2F` (`sha256:f27a0e7dba17…`); `cloud-lab:local`, built from `quay.io/frrouting/frr@sha256:fc7f887ab4d8da06f481a4f8d59afded88b3c5823f03610a7e808f7eba45eeea` |
| Repository commit | base `origin/main` at validation start; final commit recorded by PR |

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Build | `docker build -t cloud-lab:local labs/cloud-hybrid-networking/` | 4.3 s cold package layer; cached rebuild <1 s | n/a |
| Deploy | `containerlab deploy -t labs/cloud-hybrid-networking/topology.clab.yml --reconfigure` | 34.06 s | 2.62 GiB observed sampled peak after readiness; 2.46 GiB clean steady sample |
| Student path/healthy check | Manually applied the documented eBGP, propagation, policy-route, nftables, BIND-view, and resolver steps; `check.sh` | 20/20 pass | 2.62 GiB full configured sample |
| Break-It failure | `./labs/cloud-hybrid-networking/break-it.sh`; `check.sh` | n/a | HTTPS and table-101 assertions failed as intended |
| Minimal repair/check | `./labs/cloud-hybrid-networking/repair-break-it.sh`; `check.sh` | n/a | 20/20 pass after route-table repair |
| Destroy/cleanup | `containerlab destroy -t … --cleanup` | 2.6 s | no current-lab containers/namespaces/networks |
| Redeploy/recheck/destroy | clean redeploy, blank-state inspection (`BGP inactive`, no table 101), final scoped cleanup | 34.06 s deploy | same image/resource envelope |

The peak figure is a Docker-stats sample across all ten nodes, not a hardware power or
ASIC measurement. It remains below the 5 GiB steady / 7 GiB peak package target.

## Positive and negative evidence

- Positive: both cEOS hybrid sessions established; transit had both enterprise peers;
  Edge 1 learned App A with the high-distance Edge 2 backup; App A/App B resolved
  private DNS; corporate TLS reached `api.prod.corp`; inspection new-flow and
  established counters advanced; fresh TLS survived Edge 1 attachment loss and the
  primary re-established.
- Negative: untrusted DNS returned no private A record; restricted App B service did
  not answer; App A table 101 contained no App B/overlap route; cloud transit had no
  data-plane default route.
- Break-It: table 101 was changed from inspection `.13` to direct transit `.1`.
  `check.sh` failed the association assertion (and application policy evidence) until
  the one-route repair restored `.13`.

## Repository gates

```text
python3 scripts/lint-labs.py                 OK — 128 labs checked, 37 distinct images
./scripts/check-docs-admonitions.sh          OK
shellcheck -S warning scripts/*.sh labs/*/check.sh  OK
mkdocs build --strict                        OK (15.30 s; existing Material 2.0 notice and existing unnavved operations aliases only)
```

## Limitations, refresh, and cleanup

- **Unsupported or evidence-only behavior:** no cloud IAM/API/control plane, billing,
  managed-gateway HA, AZ underlay, private-circuit provisioning, provider GUI, or
  production overlap NAT. Linux policy routing is explicitly a route-table semantics model.
- **Image vulnerability-refresh review/result:** pinned FRR digest and Alpine package set
  were selected 2026-07-22. This is a lab dependency, not a vulnerability certification;
  review before the next monthly curriculum refresh.
- **Residual runtime artifacts checked:** after each scoped destroy, checked `docker ps`,
  `ip netns list`, and `docker network ls` for `cloud-hybrid-networking`; none remained.
- **Follow-ups not represented as complete:** provider-specific managed-resolver, HA,
  private-connectivity, and NAT workflows remain out of scope; WP-13 owns blind tickets.
