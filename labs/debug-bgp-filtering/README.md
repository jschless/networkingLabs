# debug-bgp-filtering — Prefix-List Applied in Wrong Direction

## Scenario

Your team operates a BGP transit network. r1 (a customer router) advertises three
prefixes: its loopback (10.0.0.1/32) and two /24s (172.16.1.0/24 and 172.16.2.0/24).
Policy requires that r2 not forward 172.16.2.0/24 beyond the r2–r3 boundary.

A network engineer configured a prefix-list on r2 to enforce this. After the change,
a downstream router (r4) reports it can still see 172.16.2.0/24. The engineer says
the filter is definitely there — "I can show you the config." But results say otherwise.

Your job: deploy the lab, use show commands to find the fault, and fix it.
**Do not look at the config files yet** — diagnose from symptoms first.

---

## Topology

```
[r1] --eBGP-- [r2] --eBGP-- [r3] --eBGP-- [r4]
AS65001       AS65002       AS65003       AS65004
```

| Link    | Subnet        | Left            | Right           |
|---------|---------------|-----------------|-----------------|
| r1 — r2 | 10.1.12.0/30  | 10.1.12.1 (r1)  | 10.1.12.2 (r2)  |
| r2 — r3 | 10.1.23.0/30  | 10.1.23.1 (r2)  | 10.1.23.2 (r3)  |
| r3 — r4 | 10.1.34.0/30  | 10.1.34.1 (r3)  | 10.1.34.2 (r4)  |

| Node | Loopback / Networks | ASN   |
|------|---------------------|-------|
| r1   | 10.0.0.1/32, 172.16.1.0/24, 172.16.2.0/24 | 65001 |
| r2   | 10.0.0.2/32 | 65002 |
| r3   | 10.0.0.3/32 | 65003 |
| r4   | 10.0.0.4/32 | 65004 |

---

## Expected behavior (when policy is correct)

- All BGP sessions Established
- r2 receives both 172.16.1.0/24 and 172.16.2.0/24 from r1
- r2 advertises 172.16.1.0/24 to r3, but **not** 172.16.2.0/24
- r3 and r4 see 172.16.1.0/24 but **not** 172.16.2.0/24
- r3's AS-path filter also correctly limits what flows to r4

---

## Deploy and access

```bash
sudo containerlab deploy -t labs/debug-bgp-filtering/topology.yml

docker exec -it clab-debug-bgp-filtering-r2 Cli
docker exec -it clab-debug-bgp-filtering-r3 Cli
docker exec -it clab-debug-bgp-filtering-r4 Cli
```

Wait ~20 seconds after deploy for BGP sessions to establish.

---

## Observed symptoms

**On r4 — 172.16.2.0/24 is visible when it should be blocked:**
```
r4# show bgp ipv4 unicast
BGP routing table information for VRF default
Router identifier 10.0.0.4, local AS number 65004
Route status codes: s - suppressed contributor, * - valid, > - active, E - ECMP head, e - ECMP
                    S - Stale, c - Contributing to ECMP, b - backup, L - labeled-unicast
                    % - Pending BGP convergence
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI Origin Validation codes: V - valid, I - invalid, U - unknown
AS Path Attributes: Or-ID - Originator ID, C-LST - Cluster List, LL Nexthop - Link Local Nexthop

          Network                Next Hop              Metric  AIGP       LocPref Weight  Path
 * >      10.0.0.1/32            10.1.34.1             0       -          100     0       65003 65002 65001 i
 * >      10.0.0.3/32            10.1.34.1             0       -          100     0       65003 i
 * >      10.0.0.4/32            -                     0       -          -       0       i
 * >      172.16.1.0/24          10.1.34.1             0       -          100     0       65003 65002 65001 i
 * >      172.16.2.0/24          10.1.34.1             0       -          100     0       65003 65002 65001 i
```

172.16.2.0/24 reached r4. The filter on r2 is not working.

**On r3 — also seeing 172.16.2.0/24:**
```
r3# show bgp ipv4 unicast
BGP routing table information for VRF default
Router identifier 10.0.0.3, local AS number 65003
...
          Network                Next Hop              Metric  AIGP       LocPref Weight  Path
 * >      10.0.0.1/32            10.1.23.1             0       -          100     0       65002 65001 i
 * >      10.0.0.3/32            -                     0       -          -       0       i
 * >      172.16.1.0/24          10.1.23.1             0       -          100     0       65002 65001 i
 * >      172.16.2.0/24          10.1.23.1             0       -          100     0       65002 65001 i
```

r3 received 172.16.2.0/24 from r2. r2's outbound filter toward r3 is not active.

---

## Your task

A prefix-list named `BLOCK-172-16-2` exists on r2 and is supposed to prevent
172.16.2.0/24 from being advertised to r3. The prefix-list definition is correct
but the effect is missing.

Work through the diagnostic questions:
1. On r2, does `show bgp ipv4 unicast` show 172.16.2.0/24 in r2's RIB?
2. On r2, what does `show bgp ipv4 unicast neighbors 10.1.23.2 advertised-routes` show?
3. On r2, what does `show bgp neighbors 10.1.23.2` say about the `BLOCK-172-16-2` filter?
4. In which direction is the prefix-list applied? Which direction was intended?

---

## Useful show commands

```
! On r2 — check r2's BGP table (does r2 have 172.16.2.0/24?)
show bgp ipv4 unicast

! On r2 — check what r2 actually advertises to r3
show bgp ipv4 unicast neighbors 10.1.23.2 advertised-routes

! On r2 — check what r2 received from r1
show bgp neighbors 10.1.12.1 received-routes

! On r2 — show neighbor config: look for 'Inbound prefix-list' / 'Outbound prefix-list'
show bgp neighbors 10.1.23.2

! After fixing: soft-reset to re-advertise without dropping session
clear bgp neighbors 10.1.23.2 soft-outbound
```

---

## Hints

<details>
<summary>Hint 1 — Where to start</summary>

On r2, run:
```
show bgp ipv4 unicast neighbors 10.1.23.2 advertised-routes
```

If 172.16.2.0/24 appears in the advertised-routes output, r2 is sending the prefix
to r3. This means the outbound filter is not working — either it doesn't exist, or
it's applied in the wrong direction.

</details>

<details>
<summary>Hint 2 — Narrowing it down</summary>

On r2, run:
```
show bgp neighbors 10.1.23.2
```

Look for lines containing:
- `Inbound prefix-list`
- `Outbound prefix-list`

Note which direction `BLOCK-172-16-2` is applied on the r3 neighbor.

A prefix-list applied `out` filters what r2 **sends** to r3.
A prefix-list applied `in` filters what r2 **receives** from r3.

</details>

<details>
<summary>Hint 3 — The specific problem</summary>

On r2, `BLOCK-172-16-2` is applied `in` on neighbor 10.1.23.2 (r3). This filters
what r2 receives FROM r3 — but r3 never sends 172.16.2.0/24 to r2 anyway (r3 only
has it if r2 sent it first). The filter has zero effect in this direction.

The filter should be applied `out` on the r3 neighbor, so that r2 blocks
172.16.2.0/24 from being included in its advertisements to r3.

</details>

---

## Solution

<details>
<summary>Fix (don't peek until you've tried the hints)</summary>

On **r2**:

```
r2# configure
r2(config)# router bgp 65002
r2(config-router-bgp)# address-family ipv4
r2(config-router-bgp-af)# no neighbor 10.1.23.2 prefix-list BLOCK-172-16-2 in
r2(config-router-bgp-af)# neighbor 10.1.23.2 prefix-list BLOCK-172-16-2 out
r2(config-router-bgp-af)# end
r2# write memory
```

Then re-advertise to r3 with the corrected filter:
```
r2# clear bgp neighbors 10.1.23.2 soft-outbound
```

</details>

---

## Verification

After applying the fix:

```
! On r2 — 172.16.2.0/24 should still be in r2's table (received from r1)
show bgp ipv4 unicast

! On r2 — 172.16.2.0/24 should now be ABSENT from advertised-routes to r3
show bgp ipv4 unicast neighbors 10.1.23.2 advertised-routes

! On r3 — 172.16.2.0/24 should be gone
show bgp ipv4 unicast

! On r4 — 172.16.2.0/24 should also be gone
show bgp ipv4 unicast
```

Expected on r3 after fix:
```
r3# show bgp ipv4 unicast
BGP routing table information for VRF default
Router identifier 10.0.0.3, local AS number 65003
...
          Network                Next Hop              Metric  AIGP       LocPref Weight  Path
 * >      10.0.0.1/32            10.1.23.1             0       -          100     0       65002 65001 i
 * >      10.0.0.3/32            -                     0       -          -       0       i
 * >      172.16.1.0/24          10.1.23.1             0       -          100     0       65002 65001 i
```

172.16.2.0/24 is gone from r3 and r4. r2 still has it locally (it was filtered outbound,
not inbound), so r2's own table still shows 172.16.2.0/24 as received from r1.
