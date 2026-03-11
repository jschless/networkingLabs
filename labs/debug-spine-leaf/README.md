# debug-spine-leaf — Missing ECMP Configuration on leaf2

## Scenario

Your data center BGP CLOS fabric has two spines and four leaves. Each leaf should
have two equal-cost paths to every other leaf — one via spine1 and one via spine2.
This dual-path design provides full bandwidth utilization and link redundancy.

After a recent deployment, traffic to and from leaf2 is only using one spine at a
time. Leaves 1, 3, and 4 show proper ECMP with two next-hops per destination.
leaf2 consistently shows only a single next-hop despite having sessions to both
spines. The BGP sessions are all up.

Your job: deploy the lab, use show commands to find the fault, and fix it.
**Do not look at the config files yet** — diagnose from symptoms first.

---

## Topology

```
        [spine1]             [spine2]
        AS65100               AS65200
   .1  .3  .5  .7        .1  .3  .5  .7
    |   |   |   |          |   |   |   |
   .0  .2  .4  .6        .0  .2  .4  .6
  eth1 eth1 eth1 eth1   eth2 eth2 eth2 eth2
[leaf1][leaf2][leaf3][leaf4]
AS65001 AS65002 AS65003 AS65004
```

### Links (/31 subnets)

| Link | Subnet | Leaf IP | Spine IP |
|------|--------|---------|----------|
| leaf1:eth1 -- spine1:eth1 | 10.1.0.0/31 | .0 | .1 |
| leaf2:eth1 -- spine1:eth2 | 10.1.0.2/31 | .2 | .3 |
| leaf3:eth1 -- spine1:eth3 | 10.1.0.4/31 | .4 | .5 |
| leaf4:eth1 -- spine1:eth4 | 10.1.0.6/31 | .6 | .7 |
| leaf1:eth2 -- spine2:eth1 | 10.2.0.0/31 | .0 | .1 |
| leaf2:eth2 -- spine2:eth2 | 10.2.0.2/31 | .2 | .3 |
| leaf3:eth2 -- spine2:eth3 | 10.2.0.4/31 | .4 | .5 |
| leaf4:eth2 -- spine2:eth4 | 10.2.0.6/31 | .6 | .7 |

| Node | Loopback | ASN |
|------|----------|-----|
| spine1 | 10.0.0.101/32 | 65100 |
| spine2 | 10.0.0.102/32 | 65200 |
| leaf1 | 10.0.0.1/32 | 65001 |
| leaf2 | 10.0.0.2/32 | 65002 |
| leaf3 | 10.0.0.3/32 | 65003 |
| leaf4 | 10.0.0.4/32 | 65004 |

---

## Expected behavior (when healthy)

- All BGP sessions Established (each leaf has 2 sessions: spine1 + spine2)
- Each leaf sees every other leaf's loopback with **2 next-hops** (ECMP via both spines)
- `show ip route bgp` on each leaf shows `[2]` multiplicity
- Traffic to and from each leaf is load-balanced across both spines

---

## Deploy and access

```bash
sudo containerlab deploy -t labs/debug-spine-leaf/topology.clab.yml

docker exec -it clab-debug-spine-leaf-leaf2  Cli
docker exec -it clab-debug-spine-leaf-leaf1  Cli
```

Wait ~25 seconds after deploy for BGP sessions to establish.

---

## Observed symptoms

**On leaf1 — correct ECMP (for comparison):**
```
leaf1# show ip route bgp
B>* 10.0.0.2/32 [20/0] via 10.1.0.1, eth1
                       via 10.2.0.1, eth2
B>* 10.0.0.3/32 [20/0] via 10.1.0.1, eth1
                       via 10.2.0.1, eth2
B>* 10.0.0.4/32 [20/0] via 10.1.0.1, eth1
                       via 10.2.0.1, eth2
```

leaf1 shows two next-hops per destination (via spine1 and spine2). ECMP is working.

**On leaf2 — single path only:**
```
leaf2# show ip route bgp
B>* 10.0.0.1/32 [20/0] via 10.1.0.3, eth1
B>* 10.0.0.3/32 [20/0] via 10.1.0.3, eth1
B>* 10.0.0.4/32 [20/0] via 10.1.0.3, eth1
```

leaf2 only shows one path (via spine1's 10.1.0.3). spine2's path is not installed
despite the BGP session being up.

**BGP sessions are up on leaf2:**
```
leaf2# show bgp ipv4 unicast summary
Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd
10.1.0.3        4      65100        18        17        0    0    0 00:01:02            5
10.2.0.3        4      65200        17        17        0    0    0 00:01:00            5
```

Both sessions Established and both are receiving 5 prefixes. But only one path
is installed in the routing table.

---

## Your task

leaf2 has two BGP sessions and is receiving routes from both spines. Yet only one
path per destination is installed in the routing table. This is a BGP multipath
configuration problem.

Work through the diagnostic questions:
1. On leaf2, what does `show bgp ipv4 unicast 10.0.0.1/32` show for number of paths?
2. On leaf1 (working), what BGP global parameters differ from leaf2?
3. What two commands are required for BGP ECMP in a DC spine-leaf fabric?
4. Why is `bgp bestpath as-path multipath-relax` specifically needed here?

---

## Useful show commands

```
! Show BGP routing table with next-hop counts
show ip route bgp

! Show all paths for a specific prefix (look for 'Paths: (2 available')
show bgp ipv4 unicast 10.0.0.1/32

! Show BGP global configuration (multipath, bestpath settings)
show bgp ipv4 unicast summary
show running-config | include maximum-paths
show running-config | include multipath

! Compare leaf2 output against leaf1 (which works correctly)
```

---

## Hints

<details>
<summary>Hint 1 — Where to start</summary>

On leaf2, run:
```
show bgp ipv4 unicast 10.0.0.1/32
```

Look at the `Paths:` line at the top. It will show how many paths are available
and which is best. If you see `(2 available, best #1)` but only one path in the
routing table, BGP has two paths but is not installing both.

For ECMP to work, BGP must be configured to install multiple equal-cost paths.

</details>

<details>
<summary>Hint 2 — Narrowing it down</summary>

BGP ECMP in a spine-leaf fabric requires two configuration statements:

1. `maximum-paths <N>` — tells BGP how many equal-cost paths to install (typically
   2 on leaves, 4 on spines).

2. `bgp bestpath as-path multipath-relax` — required because routes from spine1
   (AS65100) and spine2 (AS65200) have **different AS paths** (they each prepend
   their own AS). Without this, BGP considers them as different-attribute routes and
   won't ECMP them.

On leaf1, run `show running-config` and look for these two lines under `router bgp`.
Compare against leaf2.

</details>

<details>
<summary>Hint 3 — The specific problem</summary>

leaf2 is missing both `bgp bestpath as-path multipath-relax` and `maximum-paths 2`
in its BGP configuration. Without `multipath-relax`, the two spine paths have
different AS paths (65100 vs 65200), so only the first-received path is selected
as best. Without `maximum-paths 2`, even if both paths were considered equal, only
one would be installed.

All other leaves (leaf1, leaf3, leaf4) have both commands. leaf2 was misconfigured
during deployment.

</details>

---

## Solution

<details>
<summary>Fix (don't peek until you've tried the hints)</summary>

On **leaf2**:

```
leaf2# configure terminal
leaf2(config)# router bgp 65002
leaf2(config-router)# bgp bestpath as-path multipath-relax
leaf2(config-router)# maximum-paths 2
leaf2(config-router)# end
leaf2# write memory
```

Then trigger BGP to re-evaluate best paths:
```
leaf2# clear ip bgp * soft
```

</details>

---

## Verification

After applying the fix:

```
! On leaf2 — each destination should now show two next-hops
show ip route bgp

! On leaf2 — '(2 available, best #1)' and both paths should show as multipath
show bgp ipv4 unicast 10.0.0.1/32

! Confirm ECMP is active (both spines carry traffic)
ping 10.0.0.1 source 10.0.0.2 repeat 100
```

Expected on leaf2 after fix:
```
leaf2# show ip route bgp
B>* 10.0.0.1/32 [20/0] via 10.1.0.3, eth1
                        via 10.2.0.3, eth2
B>* 10.0.0.3/32 [20/0] via 10.1.0.3, eth1
                        via 10.2.0.3, eth2
B>* 10.0.0.4/32 [20/0] via 10.1.0.3, eth1
                        via 10.2.0.3, eth2
```

Both spines installed as equal-cost next-hops. leaf2 now has full ECMP like all
other leaves in the fabric.
