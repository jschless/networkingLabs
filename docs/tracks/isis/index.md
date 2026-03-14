# IS-IS Track

Two labs covering IS-IS fundamentals and multi-area design — essential prerequisite for the MPLS/SP track.

| Lab | Type | What You Learn |
|-----|------|----------------|
| [isis-basics](isis-basics.md) | Practice | NET address, Level-1/2, DIS election, LSP flooding |
| [isis-multiarea](isis-multiarea.md) | Practice | L1/L2/L1L2 routers, inter-area routing, route leaking |

## Platform

Both labs use **FRR 8.4** (`frr-lab:local`):
```bash
docker build -t frr-lab:local images/frr/
```
