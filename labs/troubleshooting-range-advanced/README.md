# Advanced Edge Troubleshooting Range

This proctored CCNP-level range focuses on BGP policy, routing-domain
boundaries, NAT, and path-MTU failures. Engineers receive a symptom-only
ticket, investigate normal device state, apply the smallest repair, and prove
the original service path is restored.

## Topology and golden behavior

`edge1` and `edge2` form enterprise AS 65000. Each has an eBGP provider and
they exchange routes over iBGP. ISP1 is the normal preferred path; ISP2 remains
available for failover. The internal core learns the internet service prefix
from both edges through OSPF with primary and backup metrics. Both edges have explicit source-NAT policy, and the primary
core-to-edge path has a controlled 1400-byte bottleneck for PMTUD assessment.

| Network | Purpose |
|---|---|
| `10.251.10.0/24` | Corporate clients |
| `10.251.50.0/24` | Branch clients |
| `10.251.0.0/24` | Enterprise routed transit |
| `192.0.2.0/24` | Provider transit |
| `198.18.10.0/24` | Internet test services |

## Ticket catalog

| Tier | Ticket | Domain | Time |
|---|---|---|---:|
| T2 | Backup provider relationship down | eBGP peer parameters | 35 min |
| T2 | Preferred provider accepts no service prefix | BGP prefix policy | 35 min |
| T2 | Backup edge cannot use preferred route | iBGP next-hop resolution | 35 min |
| T2 | Primary internet route missing internally | OSPF/BGP boundary | 35 min |
| T2 | Provider reports an internal prefix leak | BGP export containment | 35 min |
| T2 | Preferred provider resets after route expansion | BGP maximum-prefix | 35 min |
| T3 | Corporate internet requests receive no replies | Source NAT | 60 min |
| T3 | Large downloads stall while small requests work | PMTUD / ICMP policy | 60 min |

## Proctor workflow

```bash
./range.sh deploy
./range.sh status
./range.sh start t2-ebgp-peer-as
./range.sh verify
./range.sh reset
```

Every reset restores FRR, NAT, packet-filter, MTU, endpoint, and service state
without restarting a container.
