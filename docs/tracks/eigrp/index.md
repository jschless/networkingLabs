# EIGRP Track

Three labs covering EIGRP neighbor formation, DUAL convergence, unequal-cost load balancing, and stub configuration.

| Lab | Type | What You Learn |
|-----|------|----------------|
| [eigrp-basics](eigrp-basics.md) | Practice | Hello/dead timers, successor/FS, DUAL convergence |
| [eigrp-variance](eigrp-variance.md) | Practice | Unequal-cost load balancing, variance multiplier |
| [eigrp-stub](eigrp-stub.md) | Practice | Stub routers, leak-map, query scope reduction |

## Recommended Order

```
eigrp-basics → eigrp-variance → eigrp-stub
```

## Platform

All labs use **FRR 8.4** (`frr-lab:local`). Build once before deploying:

```bash
docker build -t frr-lab:local images/frr/
```
