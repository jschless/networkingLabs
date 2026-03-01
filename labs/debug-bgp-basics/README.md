# debug-bgp-basics — Broken iBGP Next-Hop

A four-router BGP network was recently set up to carry prefixes between
AS65001 and AS65003 through an AS65002 transit. All BGP sessions came up
immediately. But when you test end-to-end reachability, r1 cannot reach r4's
loopback (and vice versa), even though the sessions look healthy in the
summary output.

Your job: deploy the lab, use show commands to find the fault, and fix it.
**Do not look at the config files yet** — diagnose from symptoms first.

---

## Topology

```
[r1] --eBGP-- [r2] --iBGP-- [r3] --eBGP-- [r4]
AS65001       AS65002        AS65002        AS65003
```

### Link addressing

| Link    | Subnet        | Left           | Right          | Type |
|---------|---------------|----------------|----------------|------|
| r1 — r2 | 10.1.12.0/30  | 10.1.12.1 (r1) | 10.1.12.2 (r2) | eBGP |
| r2 — r3 | 10.1.23.0/30  | 10.1.23.1 (r2) | 10.1.23.2 (r3) | iBGP |
| r3 — r4 | 10.1.34.0/30  | 10.1.34.1 (r3) | 10.1.34.2 (r4) | eBGP |

| Node | Loopback    | ASN   |
|------|-------------|-------|
| r1   | 10.0.0.1/32 | 65001 |
| r2   | 10.0.0.2/32 | 65002 |
| r3   | 10.0.0.3/32 | 65002 |
| r4   | 10.0.0.4/32 | 65003 |

---

## Expected behavior (when healthy)

- All three BGP sessions in **Established** state
- All four loopback prefixes visible in the BGP table on every router
- `ping 10.0.0.4 source 10.0.0.1` from r1 succeeds
- `ping 10.0.0.1 source 10.0.0.4` from r4 succeeds

---

## Deploy and access

```bash
sudo containerlab deploy -t labs/debug-bgp-basics/topology.yml

docker exec -it clab-debug-bgp-basics-r1 vtysh
docker exec -it clab-debug-bgp-basics-r3 vtysh
```

Wait ~20 seconds after deploy for BGP sessions to establish.

---

## Observed symptoms

**On r1:**
```
r1# show bgp ipv4 unicast summary
Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd
10.1.12.2       4      65002        12        12        0    0    0 00:00:42            2
```

r1 has an Established session with r2 and sees 2 prefixes — looks fine.

**On r3:**
```
r3# show bgp ipv4 unicast summary
Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd
10.1.23.1       4      65002        14        13        0    0    0 00:00:44            2
10.1.34.2       4      65003        11        12        0    0    0 00:00:40            1
```

All three sessions Established. But:

```
r3# show bgp ipv4 unicast
   Network          Next Hop            Metric LocPrf Weight Path
*  10.0.0.1/32      10.1.12.1                              0 65001 i
*> 10.0.0.3/32      0.0.0.0                  0         32768 i
*> 10.0.0.4/32      10.1.34.2                0             0 65003 i
   10.0.0.2/32      10.1.23.1                0         32768 0 i
```

Notice 10.0.0.1/32: it has `*` (valid) but **no `>`** (not best-path selected).
r3 cannot install it in the routing table.

**End-to-end ping:**
```
r1# ping 10.0.0.4 source 10.0.0.1
5 packets transmitted, 0 received, 100% packet loss
```

---

## Your task

The BGP sessions are all up. The prefix is being advertised and received.
But r3 cannot use r1's prefix. The clue is in r3's BGP table — look at
the Next Hop column for 10.0.0.1/32.

Work through the diagnostic questions:
1. What is the next-hop for 10.0.0.1/32 as seen on r3?
2. Does r3 have a route to that next-hop address?
3. Which router is responsible for setting the next-hop when advertising to r3?
4. What single command fixes this?

---

## Useful show commands

```
! Full BGP table — look for prefixes without '>' best-path marker
show bgp ipv4 unicast

! Detailed view of a specific prefix — shows next-hop and whether it's accessible
show bgp ipv4 unicast 10.0.0.1/32

! Routing table — check if the next-hop is reachable
show ip route

! Check what next-hop-self does by looking at what r2 advertises to r3
show bgp ipv4 unicast neighbors 10.1.23.2 advertised-routes
```

---

## Hints

<details>
<summary>Hint 1 — Where to start</summary>

On r3, run:
```
show bgp ipv4 unicast 10.0.0.1/32
```

Look at the `Nexthop` field. The next-hop for this prefix is an IP address
that r3 cannot reach — it's on a subnet that r3 has no direct connection to.

</details>

<details>
<summary>Hint 2 — Narrowing it down</summary>

The next-hop for 10.0.0.1/32 on r3 is `10.1.12.1` — that's r1's address,
on the r1–r2 link. r3 has no route to 10.1.12.1.

This is the classic **iBGP next-hop problem**: when r2 received r1's prefix
via eBGP and re-advertised it via iBGP to r3, it did not change the next-hop.
The fix is `next-hop-self` on r2 for the iBGP session toward r3.

Which router needs the fix, and on which neighbor?

</details>

<details>
<summary>Hint 3 — The specific problem</summary>

On r2, `next-hop-self` is missing for neighbor `10.1.23.2` (r3) in the
address-family. Without it, r2 advertises r1's prefix to r3 with the original
next-hop of 10.1.12.1, which r3 can't reach.

</details>

---

## Solution

<details>
<summary>Fix (don't peek until you've tried the hints)</summary>

On **r2**:

```
r2# configure terminal
r2(config)# router bgp 65002
r2(config-router)# address-family ipv4 unicast
r2(config-router-af)# neighbor 10.1.23.2 next-hop-self
r2(config-router-af)# end
r2# write memory
```

Then soft-reset the session to re-advertise with the new next-hop:
```
r2# clear ip bgp 10.1.23.2 soft out
```

</details>

---

## Verification

After applying the fix:

```
! On r3 — 10.0.0.1/32 should now show '>' and next-hop 10.1.23.1 (r2)
show bgp ipv4 unicast 10.0.0.1/32

! On r3 — BGP route for r1 should now be in routing table
show ip route bgp

! End-to-end reachability
r1# ping 10.0.0.4 source 10.0.0.1
r4# ping 10.0.0.1 source 10.0.0.4
```

Expected on r3 after fix:
```
r3# show bgp ipv4 unicast 10.0.0.1/32
BGP routing table entry for 10.0.0.1/32
  ...
  10.1.23.1 from 10.1.23.1 (10.0.0.2)
    Origin IGP, metric 0, localpref 100, valid, internal, best (Nexthop)
    Nexthop: 10.1.23.1     <-- now points to r2, which r3 can reach
```
