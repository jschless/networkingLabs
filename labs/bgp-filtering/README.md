# Lab: BGP Filtering

## Overview

BGP filtering controls which routes are accepted from or advertised to peers.
Without filtering, a router accepts everything its neighbor sends — fine in a lab,
dangerous in production. This lab covers the three main filtering mechanisms:

1. **Prefix-lists** — match on the IP prefix (address + length)
2. **AS-path access-lists** — match on AS-path using regular expressions
3. **Route-maps** — combine multiple match conditions and set attributes

## Topology

```
[r1]---eth1---eth1---[r2]---eth2---eth1---[r3]---eth2---eth1---[r4]
AS65001               AS65002               AS65003               AS65004
```

r1 originates three prefixes:
- `10.0.0.1/32` — loopback
- `172.16.1.0/24` — extra prefix (sometimes permitted)
- `172.16.2.0/24` — extra prefix (filtered out by r2)

### Link Addresses

| Link             | Left side      | Right side     |
|------------------|----------------|----------------|
| r1:eth1–r2:eth1  | 10.1.12.1/30   | 10.1.12.2/30   |
| r2:eth2–r3:eth1  | 10.1.23.1/30   | 10.1.23.2/30   |
| r3:eth2–r4:eth1  | 10.1.34.1/30   | 10.1.34.2/30   |

## Deploy and Destroy

```bash
sudo containerlab deploy -t topology.yml
sudo containerlab destroy -t topology.yml
```

## Access Nodes

```bash
sudo docker exec -it clab-bgp-filtering-r1 vtysh
sudo docker exec -it clab-bgp-filtering-r2 vtysh
sudo docker exec -it clab-bgp-filtering-r3 vtysh
sudo docker exec -it clab-bgp-filtering-r4 vtysh
```

---

## Background: BGP Filtering Mechanisms

### Prefix-list

A prefix-list matches routes based on the IP prefix (network address + length).
Entries are evaluated in sequence-number order; first match wins.
An implicit `deny all` exists at the end of every prefix-list.

```
ip prefix-list NAME seq 5 deny 172.16.2.0/24
ip prefix-list NAME seq 10 permit 0.0.0.0/0 le 32
```

The `le 32` in `permit 0.0.0.0/0 le 32` means: match any prefix of length 0 to 32.
This is the standard "permit everything else" catch-all.

**Length modifiers:**

| Keyword      | Meaning                                                  |
|--------------|----------------------------------------------------------|
| (none)       | Exact match on prefix AND length                         |
| `le N`       | Match if prefix matches AND length <= N                  |
| `ge N`       | Match if prefix matches AND length >= N                  |
| `ge M le N`  | Match if prefix matches AND M <= length <= N             |

Examples:
```
! Exact match: only 10.0.0.0/24, nothing else
ip prefix-list X seq 5 permit 10.0.0.0/24

! Match /24 and all more-specific (up to /32)
ip prefix-list X seq 5 permit 10.0.0.0/24 le 32

! Match only host routes (/32) within 10.0.0.0/8
ip prefix-list X seq 5 permit 10.0.0.0/8 ge 32

! Match all prefixes between /24 and /28 within 192.168.0.0/16
ip prefix-list X seq 5 permit 192.168.0.0/16 ge 24 le 28
```

### AS-path Access-list

An AS-path access-list matches the BGP AS-path attribute using regular expressions
(POSIX extended regex). The AS-path is a string like `"65003 65002 65001"`.

```
ip as-path access-list NAME permit REGEX
ip as-path access-list NAME deny REGEX
```

**Common AS-path regex patterns:**

| Pattern       | Meaning                                                            |
|---------------|--------------------------------------------------------------------|
| `^$`          | Empty AS-path → route originated by the direct peer               |
| `^65001$`     | AS-path is exactly "65001" → originated in 65001, no transit      |
| `_65001$`     | AS-path ends with 65001 → 65001 is the origin (may have transits) |
| `_65001_`     | AS65001 appears anywhere in the path (as a transit)               |
| `^65001_`     | AS65001 is the first AS (peer's AS)                               |
| `.*`          | Match anything (use as a final permit-all)                        |

The `_` is a special token meaning "separator" — it matches: start-of-string,
space, end-of-string. It prevents partial-number matches (e.g., `65001` won't
match `65001234`).

### Filter-list vs Prefix-list vs Distribute-list

| Tool              | Matches on     | Applied via                          |
|-------------------|---------------|--------------------------------------|
| `prefix-list`     | IP prefix     | `neighbor X prefix-list NAME in/out` |
| `filter-list`     | AS-path regex | `neighbor X filter-list NAME in/out` |
| `distribute-list` | IP prefix     | `neighbor X distribute-list NAME in/out` (older, use prefix-list instead) |
| `route-map`       | Multiple attrs| `neighbor X route-map NAME in/out`  |

### soft-reconfiguration inbound

FRR can store a copy of raw received routes (before your inbound filter runs).
This lets you inspect what your neighbor actually sent without clearing the session.

```
! Enable storage of inbound pre-filter RIB
neighbor 10.1.12.1 soft-reconfiguration inbound

! Refresh the stored copy
clear ip bgp 10.1.12.1 soft in

! View pre-filter routes (what neighbor sent)
show bgp ipv4 unicast neighbors 10.1.12.1 received-routes

! View post-filter routes (what was accepted after your filter)
show bgp ipv4 unicast neighbors 10.1.12.1 routes
```

Without `soft-reconfiguration inbound`, you can still apply filters without
resetting the session using `clear ip bgp * soft in`, but you cannot inspect
the pre-filter view.

---

## Tasks

### Task 1 — Base BGP (all four routers)

Configure BGP on all four nodes. Include `no bgp ebgp-requires-policy` on all.

r1 must advertise three prefixes:
```
network 10.0.0.1/32
network 172.16.1.0/24
network 172.16.2.0/24
```

Verify on r4 — all six prefixes should be visible:
```
r4# show bgp ipv4 unicast
 * 10.0.0.1/32    (AS-path: 65003 65002 65001)
 * 10.0.0.2/32    (AS-path: 65003 65002)
 * 10.0.0.3/32    (AS-path: 65003)
 * 10.0.0.4/32    (local)
 * 172.16.1.0/24  (AS-path: 65003 65002 65001)
 * 172.16.2.0/24  (AS-path: 65003 65002 65001)
```

### Task 2 — Enable soft-reconfiguration on r2

Before adding any filters, enable the pre-filter RIB storage on r2:

```
router bgp 65002
 address-family ipv4 unicast
  neighbor 10.1.12.1 soft-reconfiguration inbound
```

Reset: `clear ip bgp 10.1.12.1 soft in`

This lets you see both before and after your filter runs:
```
r2# show bgp ipv4 unicast neighbors 10.1.12.1 received-routes
! Shows everything r1 sent
r2# show bgp ipv4 unicast neighbors 10.1.12.1 routes
! Shows only what passed your inbound filter
```

### Task 3 — Inbound prefix-list on r2: block 172.16.2.0/24

```
ip prefix-list BLOCK-172-16-2 seq 5 deny 172.16.2.0/24
ip prefix-list BLOCK-172-16-2 seq 10 permit 0.0.0.0/0 le 32

router bgp 65002
 address-family ipv4 unicast
  neighbor 10.1.12.1 prefix-list BLOCK-172-16-2 in
```

Apply: `clear ip bgp * soft in`

Expected:
- r2's BGP table: 172.16.2.0/24 absent, 172.16.1.0/24 present
- r2's received-routes: both still visible
- r4: 172.16.2.0/24 absent (was never forwarded by r2)

### Task 4 — AS-path filter on r3: only accept routes from AS65001

```
ip as-path access-list ONLY-AS65001 permit _65001$
ip as-path access-list ONLY-AS65001 deny .*

router bgp 65003
 address-family ipv4 unicast
  neighbor 10.1.23.1 filter-list ONLY-AS65001 in
```

Apply: `clear ip bgp * soft in`

With this filter, r3 only accepts routes where AS65001 is the origin AS.
Routes from r2 (10.0.0.2/32) and r3 itself (10.0.0.3/32) are NOT from AS65001,
so r3 won't install r2's loopback from r2 (path "65002") via this neighbor.

Verify on r4:
- Routes with AS65001 origin are present
- Routes with only AS65002 in the path may be absent

### Task 5 — Outbound prefix-list on r1: control what r1 advertises

Instead of filtering at r2, filter at the source. On r1, only send the loopback
to r2 — suppress the /24 prefixes outbound:

```
ip prefix-list LOOPBACK-ONLY seq 5 permit 10.0.0.1/32
ip prefix-list LOOPBACK-ONLY seq 10 deny 0.0.0.0/0 le 32

router bgp 65001
 address-family ipv4 unicast
  neighbor 10.1.12.2 prefix-list LOOPBACK-ONLY out
```

Apply: `clear ip bgp * soft out` on r1

r2 will now only receive 10.0.0.1/32 from r1.

### Task 6 — Combine prefix-list and attribute-setting in a route-map

On r2, instead of a pure deny/permit, use a route-map that:
- Accepts 172.16.1.0/24 with local-pref 150
- Denies 172.16.2.0/24
- Accepts everything else at default

```
ip prefix-list WANT-172-16-1 seq 5 permit 172.16.1.0/24
ip prefix-list UNWANTED seq 5 permit 172.16.2.0/24

route-map FROM-R1 permit 10
 match ip address prefix-list WANT-172-16-1
 set local-preference 150
route-map FROM-R1 deny 20
 match ip address prefix-list UNWANTED
route-map FROM-R1 permit 30

router bgp 65002
 address-family ipv4 unicast
  neighbor 10.1.12.1 route-map FROM-R1 in
```

---

## Useful Show Commands

```
show bgp ipv4 unicast                                     # BGP table
show bgp ipv4 unicast 172.16.2.0/24                      # Detail for specific prefix
show bgp neighbors 10.1.12.1 received-routes             # Pre-filter (needs soft-reconfig)
show bgp neighbors 10.1.12.1 routes                      # Post-filter accepted routes
show bgp neighbors 10.1.12.1 advertised-routes           # What we send to neighbor
show ip prefix-list                                       # All prefix-lists
show ip as-path-access-list                              # All AS-path access-lists
show route-map                                            # All route-maps
show ip bgp summary                                       # Session status
```

## Troubleshooting

**Filter not taking effect**
- Run `clear ip bgp * soft in` (inbound filter) or `clear ip bgp * soft out` (outbound)
- Without a soft reset, existing routes keep their old filter decisions

**Prefix-list matching too much or too little**
- Test specifics: `show bgp ipv4 unicast` and look for unexpected presence/absence
- Use `show ip prefix-list NAME` to see the list entries
- Remember: implicit deny-all at end of every prefix-list

**AS-path regex not matching**
- Test with: `show bgp ipv4 unicast regexp _65001$` (shows all routes matching regex)
- Use `_` not `.` as a word separator — `.` in regex matches any character
- `^65001$` matches ONLY "65001" exactly (one-hop AS-path)
- `_65001$` matches "65001" at the end of any longer path

**filter-list vs prefix-list applied together**
- You can apply both a prefix-list AND a filter-list to the same neighbor
- Both must permit the route for it to be accepted
