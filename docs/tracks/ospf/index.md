# OSPF Track

Nine labs covering OSPF from single-area basics through multi-area design, authentication, summarization, redistribution, and OSPFv3 for IPv6.

| Lab | Type | What You Learn |
|-----|------|----------------|
| [two-routers](two-routers.md) | Practice | Single-area OSPF, ContainerLab basics |
| [ospf-multiarea](ospf-multiarea.md) | Practice | Multi-area OSPF, ABRs, stub areas |
| [ospf-auth](ospf-auth.md) | Practice | OSPF MD5 authentication, key mismatches |
| [ospf-summarization](ospf-summarization.md) | Practice | Inter-area and external summarization |
| [ospf-default-route](ospf-default-route.md) | Practice | `default-information originate`, conditional default |
| [ospf-nssa](ospf-nssa.md) | Practice | Not-So-Stubby Area, Type-7 LSAs |
| [ospf-virtual-link](ospf-virtual-link.md) | Practice | Virtual links, discontiguous area 0 |
| [ospf-bgp-redist](ospf-bgp-redist.md) | Practice | Mutual OSPF↔BGP redistribution at an ASBR |
| [ipv6-ospf3](ipv6-ospf3.md) | Practice | OSPFv3, link-local next-hops, IPv6 areas |

## Recommended Order

```
two-routers → ospf-multiarea → ospf-auth → ospf-summarization
→ ospf-default-route → ospf-nssa → ospf-virtual-link
→ ospf-bgp-redist → ipv6-ospf3
```

## Platform

All labs use **Arista cEOS**:

```bash
docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F
```
