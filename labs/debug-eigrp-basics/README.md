# debug-eigrp-basics — EIGRP AS Number Mismatch

## Scenario

A colleague finished configuring a new square EIGRP topology connecting four routers.
All adjacencies appeared to form on their screen, but only three of the four routers
are showing up in anyone else's neighbor tables this morning. r3 is reachable from
its own console, but none of the other routers know it exists.

Your job: deploy the lab, use show commands to find the fault, and fix it.
**Do not look at the config files yet** — diagnose from symptoms first.

---

## Topology

```
[r1] ---10.1.12.0/30--- [r2]
 |                         |
10.1.13.0/30         10.1.24.0/30
 |                         |
[r3] ---10.1.34.0/30--- [r4]
```

| Node | Loopback    | Interface IPs |
|------|-------------|---------------|
| r1   | 10.0.0.1/32 | eth1=10.1.12.1, eth2=10.1.13.1 |
| r2   | 10.0.0.2/32 | eth1=10.1.12.2, eth2=10.1.24.1 |
| r3   | 10.0.0.3/32 | eth1=10.1.13.2, eth2=10.1.34.1 |
| r4   | 10.0.0.4/32 | eth1=10.1.24.2, eth2=10.1.34.2 |

---

## Expected behavior (when healthy)

- All four EIGRP adjacencies formed: r1–r2, r1–r3, r2–r4, r3–r4
- All four loopbacks (10.0.0.1–10.0.0.4/32) visible in the EIGRP topology table
- Two equal-cost paths from r1 to r4 (via r2 and via r3)
- `ping 10.0.0.4 source 10.0.0.1` from r1 succeeds

---

## Deploy and access

```bash
sudo containerlab deploy -t labs/debug-eigrp-basics/topology.yml

docker exec -it clab-debug-eigrp-basics-r1 vtysh
docker exec -it clab-debug-eigrp-basics-r3 vtysh
docker exec -it clab-debug-eigrp-basics-r4 vtysh
```

Wait ~15 seconds after deploy for EIGRP hello timers to expire.

---

## Observed symptoms

**On r1 — only one of two expected neighbors:**
```
r1# show ip eigrp neighbors
EIGRP neighbors for AS(100)
H   Address         Interface       Hold Uptime   SRTT   RTO  Q  Seq
                                    (sec)         (ms)       Cnt Num
0   10.1.12.2       eth1              13 00:00:42    1   200  0  6
```

r1 sees r2 (eth1) but r3 (eth2) is absent.

**On r3 — no neighbors at all:**
```
r3# show ip eigrp neighbors
(no output)
```

**On r4 — only r2, not r3:**
```
r4# show ip eigrp neighbors
EIGRP neighbors for AS(100)
H   Address         Interface       Hold Uptime   SRTT   RTO  Q  Seq
                                    (sec)         (ms)       Cnt Num
0   10.1.24.1       eth1              12 00:00:38    1   200  0  5
```

r4 sees r2 but not r3.

**Routing impact:**
```
r1# show ip route eigrp
D>* 10.0.0.2/32 [90/10880] via 10.1.12.2, eth1
D>* 10.0.0.4/32 [90/11264] via 10.1.12.2, eth1
D>* 10.1.24.0/30 [90/10880] via 10.1.12.2, eth1
```

Only one path to r4 (via r2). r3's loopback (10.0.0.3/32) is completely absent.

---

## Your task

r3 is running EIGRP, r3's interfaces are up, but no neighbor relationships form.
When EIGRP hellos are sent, neighbors will only respond if they share the same
Autonomous System number.

Work through the diagnostic questions:
1. On r3, what does `show ip eigrp neighbors` show?
2. On r1 and r4, are r3's interface addresses visible as neighbors?
3. On r3, what does `show ip eigrp topology` show?
4. What single EIGRP parameter controls whether neighbors will form?

---

## Useful show commands

```
! Check adjacencies — who is r3 peering with?
show ip eigrp neighbors

! Check topology table — what routes does r3 know about?
show ip eigrp topology

! Verify EIGRP process details (AS number, router-id)
show ip eigrp

! From r1: confirm r3's interface IP is not in the neighbor table
show ip eigrp neighbors detail
```

---

## Hints

<details>
<summary>Hint 1 — Where to start</summary>

On r3, run:
```
show ip eigrp neighbors
```

If the output is empty (no neighbors), r3 is not forming adjacencies with anyone.
EIGRP hellos are being exchanged at the link layer, but something is preventing
them from being accepted.

Compare: on r1, run `show ip eigrp neighbors` — is r3's address (10.1.13.2) present?

</details>

<details>
<summary>Hint 2 — Narrowing it down</summary>

EIGRP adjacencies only form between routers in the **same Autonomous System number**.
When router A sends a hello with AS 100 and router B is configured for AS 101,
B will silently ignore the hello. No error is logged; the hello simply doesn't match.

On r3, run:
```
show ip eigrp
```

Look at the `AS(X)` value in the output. Compare it with what r1 shows.

</details>

<details>
<summary>Hint 3 — The specific problem</summary>

r3 is configured with `router eigrp 101` instead of `router eigrp 100`. All other
routers use AS 100. Because the AS number doesn't match, r3's hellos are ignored
by r1 and r4, and vice versa. r3 appears isolated.

</details>

---

## Solution

<details>
<summary>Fix (don't peek until you've tried the hints)</summary>

On **r3**:

```
r3# configure terminal
r3(config)# no router eigrp 101
r3(config)# router eigrp 100
r3(config-router)# eigrp router-id 10.0.0.3
r3(config-router)# network 0.0.0.0/0
r3(config-router)# passive-interface lo
r3(config-router)# end
r3# write memory
```

The wrong AS process is removed and replaced with the correct one. EIGRP hellos
will now match on r1 and r4, and adjacencies will form within seconds.

</details>

---

## Verification

After applying the fix:

```
! On r3 — neighbors should now appear
show ip eigrp neighbors

! On r1 — two equal-cost paths to r4 via r2 and r3
show ip eigrp topology 10.0.0.4/32
show ip route eigrp

! End-to-end reachability
r1# ping 10.0.0.4 source 10.0.0.1
```

Expected on r1 after fix:
```
r1# show ip route eigrp
D>* 10.0.0.2/32 [90/10880] via 10.1.12.2, eth1
D>* 10.0.0.3/32 [90/10880] via 10.1.13.2, eth2
D>* 10.0.0.4/32 [90/11264] via 10.1.12.2, eth1
                            via 10.1.13.2, eth2
D>* 10.1.24.0/30 [90/10880] via 10.1.12.2, eth1
D>* 10.1.34.0/30 [90/10880] via 10.1.13.2, eth2
```

Both paths to r4 installed — ECMP via r2 and r3.
