# Lab: EIGRP Stub Routers

## Topology

```
        [spoke1] 10.0.0.2
       / 10.1.11.0/30
[hub] 10.0.0.1
       \ 10.1.12.0/30
        [spoke2] 10.0.0.3
       \ 10.1.13.0/30
        [spoke3] 10.0.0.4
              \ 10.1.30.0/30
               [ce] 10.0.0.5
```

| Link | Subnet | hub/spoke side | spoke/ce side |
|------|--------|---------------|--------------|
| hub:eth1 - spoke1:eth1 | 10.1.11.0/30 | hub=.1 | spoke1=.2 |
| hub:eth2 - spoke2:eth1 | 10.1.12.0/30 | hub=.1 | spoke2=.2 |
| hub:eth3 - spoke3:eth1 | 10.1.13.0/30 | hub=.1 | spoke3=.2 |
| spoke3:eth2 - ce:eth1  | 10.1.30.0/30 | spoke3=.1 | ce=.2 |

Loopbacks: hub=10.0.0.1/32, spoke1=10.0.0.2/32, spoke2=10.0.0.3/32,
           spoke3=10.0.0.4/32, ce=10.0.0.5/32

## Concepts

### Why EIGRP Queries Cause Problems

When EIGRP loses a route and has no Feasible Successor, it sends a **Query**
to every neighbor asking "do you have a path to this destination?"

In a hub-and-spoke network:
1. Hub loses a route (e.g., a link goes down)
2. Hub sends queries to ALL neighbors — including all spokes
3. Spokes don't have alternate paths and must reply "No"
4. If a spoke is slow to reply (congestion, overloaded), the hub keeps
   the route in **Active** state, waiting
5. If the reply doesn't arrive within the active timer (3 min default),
   the route goes **Stuck In Active (SIA)** — EIGRP resets the neighbor

SIA causes neighbor resets, which cause reconvergence, which causes more
queries. In large networks this cascades.

### Stub Router: The Solution

A stub router tells its neighbors: "I am a dead end — don't send me queries."

When the hub knows spoke1 is a stub:
- The hub will **not** send queries to spoke1 when a route goes active
- The hub marks spoke1's routes as "not usable as transit"
- The query scope is limited to non-stub peers only

This dramatically reduces query propagation depth and eliminates SIA
on spoke routers that have no alternate paths anyway.

### Stub Modes

```
eigrp stub                          # connected routes only
eigrp stub connected                # connected routes only (explicit)
eigrp stub connected summary        # connected + summary routes
eigrp stub receive-only             # no routes advertised at all
eigrp stub leak-map MAPNAME         # connected + what leak-map permits
```

The most common production mode is `eigrp stub connected summary`.

### Leak-Map

A stub router by default only advertises connected and/or summary routes.
If a stub has downstream networks that non-stub routers need to know about,
use a **leak-map** to selectively allow those prefixes through.

```
ip prefix-list LEAK-CE permit 10.1.30.0/30
ip prefix-list LEAK-CE permit 10.0.0.5/32

route-map LEAK-MAP permit 10
 match ip address prefix-list LEAK-CE

router eigrp 100
 eigrp stub connected summary leak-map LEAK-MAP
```

spoke3 will still be treated as stub (hub won't query it), but it will
advertise ce's networks to the hub.

## Deployment

```bash
sudo containerlab deploy -t topology.clab.yml
```

## Tasks

### Step 1: Configure EIGRP on all nodes (no stub yet)

On each node:
```
router eigrp 100
 network <loopback>/32
 network <link-subnet>/30
 no auto-summary
```

Verify full convergence from hub:
```
show ip eigrp neighbors
show ip route eigrp
ping 10.0.0.5 source 10.0.0.1
```

### Step 2: Configure spoke1 and spoke2 as stub

On spoke1:
```
router eigrp 100
 eigrp stub connected summary
```

On spoke2:
```
router eigrp 100
 eigrp stub connected summary
```

Verify on hub:
```
show ip eigrp neighbors detail
```

Look for:
```
EIGRP-IPv4 Neighbors for AS(100)
...
Peer-type is Stub
```

### Step 3: Configure spoke3 as stub with leak-map

On spoke3:
```
ip prefix-list LEAK-CE seq 5 permit 10.1.30.0/30
ip prefix-list LEAK-CE seq 10 permit 10.0.0.5/32

route-map LEAK-MAP permit 10
 match ip address prefix-list LEAK-CE

router eigrp 100
 eigrp stub connected summary leak-map LEAK-MAP
```

Verify ce's prefix is still reachable from hub:
```
show ip route 10.0.0.5
ping 10.0.0.5 source 10.0.0.1
```

### Step 4: Observe query behaviour

Enable debug on hub:
```
debug eigrp packets query
```

Simulate a link failure:
```bash
# From the hub Linux shell (outside vtysh):
ip link set eth3 down
```

Watch the debug output. The hub should NOT send queries to spoke1 or
spoke2 (they are stub). It will only query stub-exempt neighbors.

Restore the link:
```bash
ip link set eth3 up
```

## Verification Commands

| Command | Where | What to look for |
|---------|-------|-----------------|
| `show ip eigrp neighbors` | all | All neighbors up |
| `show ip eigrp neighbors detail` | hub | Stub flag on spokes |
| `show ip eigrp topology` | hub | Routes via each spoke |
| `show ip route eigrp` | hub | ce's prefixes via spoke3 |
| `ping 10.0.0.5 source 10.0.0.1` | hub | ce reachable after stub |
| `debug eigrp packets query` | hub | No queries to stub peers |

## Stub Flags in Neighbor Detail

```
show ip eigrp neighbors detail

EIGRP-IPv4 VR(eigrp-lab) Address-Family Neighbors for AS(100)
H   Address   Interface   Hold  Uptime  SRTT   RTO  Q  Seq
                          (sec)         (ms)       Cnt Num
0   10.1.11.2 eth1          12  00:02:14   8   200  0   14
   Version 3.0/2.0, Retrans: 1, Retries: 0
   Topology-ids from peer - 0
   Peer-type is Stub, is not Transit, is Connected
```

The key line is **"Peer-type is Stub"** — this confirms the hub has
received the stub flag from the spoke.

## Key Takeaways

- Stub routers reduce query scope and prevent SIA in hub-and-spoke designs
- Stub does NOT prevent the stub router from learning routes
- Stub DOES prevent the hub from using the stub as a transit path
- Use leak-map when a stub has downstream prefixes to share
- Always verify stub flags with `show ip eigrp neighbors detail`

## Teardown

```bash
sudo containerlab destroy -t topology.clab.yml
```
