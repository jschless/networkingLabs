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
sudo containerlab destroy -t topology.yml --cleanup
```

## Access Nodes

```bash
docker exec -it clab-bgp-filtering-r1 Cli
docker exec -it clab-bgp-filtering-r2 Cli
docker exec -it clab-bgp-filtering-r3 Cli
docker exec -it clab-bgp-filtering-r4 Cli
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

| Tool              | Matches on     | Applied via                              |
|-------------------|----------------|------------------------------------------|
| `prefix-list`     | IP prefix      | `neighbor X prefix-list NAME in/out`    |
| AS-path filter    | AS-path regex  | Define `ip as-path access-list`, reference via `route-map` + `match as-path` |
| `route-map`       | Multiple attrs | `neighbor X route-map NAME in/out`      |

**Note:** EOS does not have `neighbor X filter-list`. AS-path access-lists must be
applied via a route-map using `match as-path NAME`.

### Received Routes in EOS

In EOS, received routes from neighbors are stored automatically — no additional
configuration is required. You can inspect pre-filter routes at any time:

```
! What the neighbor sent (pre-filter, raw from peer)
show bgp neighbors 10.1.12.1 received-routes

! What was accepted after your inbound filter ran
show bgp neighbors 10.1.12.1 routes
```

This works natively without enabling any soft-reconfiguration option.

---

## Tasks

### Task 1 — Base BGP (all four routers)

Configure BGP on all four nodes. EOS does not require `no bgp ebgp-requires-policy`.

r1 must advertise three prefixes:
```
network 10.0.0.1/32
network 172.16.1.0/24
network 172.16.2.0/24
```

Example on r1:
```
r1(config)# router bgp 65001
r1(config-router-bgp)# bgp router-id 10.0.0.1
r1(config-router-bgp)# neighbor 10.1.12.2 remote-as 65002
r1(config-router-bgp)# address-family ipv4
r1(config-router-bgp-af)# neighbor 10.1.12.2 activate
r1(config-router-bgp-af)# network 10.0.0.1/32
r1(config-router-bgp-af)# network 172.16.1.0/24
r1(config-router-bgp-af)# network 172.16.2.0/24
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

### Task 2 — Inbound prefix-list on r2: block 172.16.2.0/24

```
r2(config)# ip prefix-list BLOCK-172-16-2 seq 5 deny 172.16.2.0/24
r2(config)# ip prefix-list BLOCK-172-16-2 seq 10 permit 0.0.0.0/0 le 32
r2(config)# router bgp 65002
r2(config-router-bgp)# address-family ipv4
r2(config-router-bgp-af)# neighbor 10.1.12.1 prefix-list BLOCK-172-16-2 in
```

Apply: `clear bgp neighbors 10.1.12.1 soft-inbound`

Expected:
- r2's BGP table: 172.16.2.0/24 absent, 172.16.1.0/24 present
- r2's received-routes: both still visible (pre-filter view)
- r4: 172.16.2.0/24 absent (was never forwarded by r2)

Verify pre- and post-filter:
```
r2# show bgp neighbors 10.1.12.1 received-routes
! Shows everything r1 sent (both /24s visible here)
r2# show bgp neighbors 10.1.12.1 routes
! Shows only what passed the inbound filter (172.16.2.0/24 absent)
```

### Task 3 — AS-path filter on r3: only accept routes from AS65001

EOS does not have `neighbor filter-list`. Apply AS-path filters via a route-map:

```
r3(config)# ip as-path access-list ONLY-AS65001 permit _65001$
r3(config)# route-map ASPATH-IN permit 10
r3(config-route-map-ASPATH-IN)# match as-path ONLY-AS65001
r3(config)# router bgp 65003
r3(config-router-bgp)# address-family ipv4
r3(config-router-bgp-af)# neighbor 10.1.23.1 route-map ASPATH-IN in
```

Apply: `clear bgp neighbors 10.1.23.1 soft-inbound`

With this filter, r3 only accepts routes where AS65001 is the origin AS.
Routes from r2 (10.0.0.2/32) and r3 itself (10.0.0.3/32) are NOT from AS65001,
so r3 won't install r2's loopback from r2 (path "65002") via this neighbor.

Verify on r4:
- Routes with AS65001 origin are present
- Routes with only AS65002 in the path may be absent

### Task 4 — Outbound prefix-list on r1: control what r1 advertises

Instead of filtering at r2, filter at the source. On r1, only send the loopback
to r2 — suppress the /24 prefixes outbound:

```
r1(config)# ip prefix-list LOOPBACK-ONLY seq 5 permit 10.0.0.1/32
r1(config)# ip prefix-list LOOPBACK-ONLY seq 10 deny 0.0.0.0/0 le 32
r1(config)# router bgp 65001
r1(config-router-bgp)# address-family ipv4
r1(config-router-bgp-af)# neighbor 10.1.12.2 prefix-list LOOPBACK-ONLY out
```

Apply: `clear bgp * soft-outbound` on r1

r2 will now only receive 10.0.0.1/32 from r1.

### Task 5 — Combine prefix-list and attribute-setting in a route-map

On r2, instead of a pure deny/permit, use a route-map that:
- Accepts 172.16.1.0/24 with local-pref 150
- Denies 172.16.2.0/24
- Accepts everything else at default

```
r2(config)# ip prefix-list WANT-172-16-1 seq 5 permit 172.16.1.0/24
r2(config)# ip prefix-list UNWANTED seq 5 permit 172.16.2.0/24
r2(config)# route-map FROM-R1 permit 10
r2(config-route-map-FROM-R1)# match ip address prefix-list WANT-172-16-1
r2(config-route-map-FROM-R1)# set local-preference 150
r2(config)# route-map FROM-R1 deny 20
r2(config-route-map-FROM-R1)# match ip address prefix-list UNWANTED
r2(config)# route-map FROM-R1 permit 30
r2(config)# router bgp 65002
r2(config-router-bgp)# address-family ipv4
r2(config-router-bgp-af)# neighbor 10.1.12.1 route-map FROM-R1 in
```

---

## Useful Show Commands

```
show bgp ipv4 unicast                                     ! BGP table
show bgp ipv4 unicast 172.16.2.0/24                      ! Detail for specific prefix
show bgp neighbors 10.1.12.1 received-routes             ! Pre-filter (what neighbor sent)
show bgp neighbors 10.1.12.1 routes                      ! Post-filter accepted routes
show bgp neighbors 10.1.12.1 advertised-routes           ! What we send to neighbor
show ip prefix-list                                       ! All prefix-lists
show ip as-path                                           ! All AS-path access-lists
show route-map                                            ! All route-maps
show bgp ipv4 unicast summary                            ! Session status
show running-config | grep prefix-list                   ! Search running config
```

## Troubleshooting

**Filter not taking effect**
- Run `clear bgp * soft-inbound` (inbound filter) or `clear bgp * soft-outbound` (outbound)
- You can also target a specific neighbor: `clear bgp neighbors 10.1.12.1 soft-inbound`
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

**Combining AS-path and prefix filters**
- In EOS, combine them in a single route-map with multiple match conditions, or chain two route-maps
- Both conditions must permit the route for it to be accepted
