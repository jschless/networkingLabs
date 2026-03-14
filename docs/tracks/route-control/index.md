# Route Control & Redistribution Track

Three labs covering redistribution loop prevention, policy-based routing, and IP SLA object tracking.

| Lab | Type | What You Learn |
|-----|------|----------------|
| [redistribution-tags](redistribution-tags.md) | Practice | Tag-based loop prevention in OSPF↔EIGRP redistribution |
| [route-maps-pbr](route-maps-pbr.md) | Practice | Policy-based routing, match source/dest, set next-hop |
| [ip-sla-tracking](ip-sla-tracking.md) | Practice | IP SLA probes, object tracking, floating static routes |

## Platform

All labs use **FRR 8.4** (`frr-lab:local`):
```bash
docker build -t frr-lab:local images/frr/
```
