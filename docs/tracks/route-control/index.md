# Route Control & Redistribution Track

Three labs covering redistribution loop prevention, policy-based routing, and IP SLA object tracking.

| Lab | Type | What You Learn |
|-----|------|----------------|
| [redistribution-tags](redistribution-tags.md) | Practice | Tag-based loop prevention in OSPF↔EIGRP redistribution |
| [route-maps-pbr](route-maps-pbr.md) | Practice | Policy-based routing, match source/dest, set next-hop |
| [ip-sla-tracking](ip-sla-tracking.md) | Practice | IP SLA probes, object tracking, floating static routes |

## Platform

All labs use **Arista cEOS**:
```bash
docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F
```
