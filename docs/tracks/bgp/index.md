# BGP Track

Nine labs from basic eBGP/iBGP sessions through path selection, filtering, communities, aggregation, security (RPKI), labeled unicast, and dual-stack IPv6.

| Lab | Type | What You Learn |
|-----|------|----------------|
| [bgp-basics](bgp-basics.md) | Practice | eBGP/iBGP sessions, next-hop problem, split-horizon |
| [bgp-path-selection](bgp-path-selection.md) | Practice | Weight → LP → AS-path → MED, step by step |
| [bgp-filtering](bgp-filtering.md) | Practice | Prefix-lists, AS-path ACLs, distribute-lists |
| [bgp-communities](bgp-communities.md) | Practice | Standard/extended communities, route-map tagging |
| [bgp-aggregation](bgp-aggregation.md) | Practice | `aggregate-address`, summary-only, selective suppression |
| [bgp-prefix-security](bgp-prefix-security.md) | Practice | Route hijacking demo, prefix-list defenses, RPKI concepts |
| [bgp-rpki](bgp-rpki.md) | Practice | BGP RPKI, Route Origin Validation, ROA validation with rpkid |
| [bgp-labeled-unicast](bgp-labeled-unicast.md) | Practice | BGP-LU (RFC 3107), inter-AS MPLS label distribution |
| [ipv6-bgp](ipv6-bgp.md) | Practice | Dual-stack BGP, extended next-hop, native IPv6 sessions |

## Recommended Order

```
bgp-basics → bgp-path-selection → bgp-filtering → bgp-communities
→ bgp-aggregation → bgp-prefix-security → bgp-rpki
→ bgp-labeled-unicast → ipv6-bgp
```

## Platform

All labs use **FRR 8.4** (`frr-lab:local`):
```bash
docker build -t frr-lab:local images/frr/
```
