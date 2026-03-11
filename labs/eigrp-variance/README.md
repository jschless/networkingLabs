# Lab: EIGRP Variance (Unequal-Cost Load Balancing)

## Topology

```
[r1] ---eth1/eth1 (fast, 10000K)--- [r2] ---eth2/eth1--- [r4]
  \                                                      /
   ---eth2/eth1 (slow, 1000K)--- [r3] ---eth2/eth2-----
```

| Link         | Subnet        | r1 side | r2/r3/r4 side | Bandwidth   |
|--------------|---------------|---------|---------------|-------------|
| r1:eth1 - r2:eth1 | 10.1.12.0/30 | .1 | .2 | 10000 Kbps |
| r1:eth2 - r3:eth1 | 10.1.13.0/30 | .1 | .2 | 1000 Kbps  |
| r2:eth2 - r4:eth1 | 10.1.24.0/30 | .1 | .2 | default    |
| r3:eth2 - r4:eth2 | 10.1.34.0/30 | .1 | .2 | default    |

Loopbacks: r1=10.0.0.1/32, r2=10.0.0.2/32, r3=10.0.0.3/32, r4=10.0.0.4/32

## Concepts

### EIGRP Default: Equal-Cost Only (variance 1)

By default, EIGRP sets `variance 1`. This means only routes with metric equal
to the Successor's Feasible Distance (FD) are installed in the routing table.
This is identical behaviour to OSPF/IS-IS — ECMP only.

### EIGRP Metric

EIGRP metric is computed from bandwidth and delay (classic metric):

```
metric = (K1 * bandwidth + K3 * delay) * 256
```

Where bandwidth is the minimum bandwidth (in Kbps) along the path, and delay
is the cumulative delay. A lower bandwidth produces a *higher* metric.

Because r1:eth2 is set to 1000 Kbps (vs 10000 Kbps on r1:eth1), the path
through r3 will have a higher metric than the path through r2.

### Feasibility Condition (FC)

For a route to be a Feasible Successor (backup path), it must satisfy:

```
Reported Distance (RD) from neighbor < current Feasible Distance (FD)
```

The RD is the neighbor's metric to the destination. The FC ensures loop-free
alternates — a neighbor whose distance to the destination is less than yours
cannot be routing through you.

### variance N

```
router eigrp 100
 variance 2
```

With `variance 2`, EIGRP installs all Feasible Successor paths whose metric is
**≤ 2 × the Successor's FD**. The path must still satisfy the Feasibility
Condition.

### Proportional Load Balancing

Unlike OSPF (which distributes traffic equally across equal-cost paths), EIGRP
distributes traffic **inversely proportional to the metric**:

- If Successor metric = 1000 and FS metric = 1800, more traffic goes via the
  Successor.
- The ratio is roughly metric_FS / metric_S packets via Successor for every
  1 packet via FS.

This is set with `traffic-share balanced` (the default).

## Deployment

```bash
sudo containerlab deploy -t topology.clab.yml
```

## Tasks

### Step 1: Configure EIGRP on all nodes

On each router (r1, r2, r3, r4), enter vtysh and configure:

```
router eigrp 100
 network 10.0.0.X/32
 network 10.1.XY.0/30
 no auto-summary
```

Note: FRR EIGRP accepts prefix notation in the network statement.

### Step 2: Verify convergence (before variance)

```
show ip eigrp neighbors
show ip eigrp topology
show ip route eigrp
```

From r1, you should see ONE path to 10.0.0.4/32 (via r2, the fast path).
The path via r3 may appear as Feasible Successor in the topology table
if it meets the FC.

### Step 3: Check topology table detail

```
show ip eigrp topology 10.0.0.4/32
```

Look for:
- `FD is XXXXX` — the Feasible Distance (metric via Successor)
- Successor: via 10.1.12.2 (r2)
- Feasible Successor: via 10.1.13.2 (r3) — only if RD from r3 < FD via r2

If r3 does NOT appear as FS, the path via r3 does not meet the FC and variance
will not install it. This is intentional safety behaviour.

### Step 4: Add variance

```
router eigrp 100
 variance 2
```

### Step 5: Verify unequal-cost paths installed

```
show ip route 10.0.0.4
```

Expected output (two paths):
```
D   10.0.0.4/32 [90/XXXXX] via 10.1.12.2, eth1
                [90/YYYYY] via 10.1.13.2, eth2
```

Where YYYYY > XXXXX (higher metric via slow path).

## Verification Commands

| Command | What to look for |
|---------|-----------------|
| `show ip eigrp neighbors` | All four neighbors up |
| `show ip eigrp topology` | Successor and FS for each prefix |
| `show ip eigrp topology 10.0.0.4/32` | FD and RD values for each path |
| `show ip route eigrp` | Two entries for 10.0.0.4 after variance |
| `ping 10.0.0.4 source 10.0.0.1` | Should succeed |

## Key Differences vs OSPF

| Feature | OSPF | EIGRP |
|---------|------|-------|
| Load balancing | Equal-cost only | Unequal-cost (with variance) |
| Traffic distribution | Even split | Proportional to inverse metric |
| Backup paths | Not installed | Feasible Successors (fast failover) |
| Path selection | Dijkstra (SPF) | DUAL algorithm |

## Teardown

```bash
sudo containerlab destroy -t topology.clab.yml
```
