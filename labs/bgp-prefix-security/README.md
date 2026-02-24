# Lab: BGP Prefix Security (Route Hijacking & Defenses)

## Purpose
Demonstrate how BGP route hijacking works in practice and how to defend against it using prefix-lists, max-prefix limits, and (conceptually) RPKI.

## Topology

```
[legitimate]            [hijacker]
 AS65001                AS65002
 192.0.2.0/24           (fraudulent 192.0.2.0/24)
     |                       |
  eth1:10.1.11.1          eth1:10.1.12.2
     |                       |
  10.1.11.2               10.1.12.1
     \                       /
            [isp]
            AS65100
          10.1.13.1
              |
           10.1.13.2
              |
           [victim]
            AS65003
```

## Address Plan

| Node | Interface | Address |
|------|-----------|---------|
| legitimate | lo | 10.0.0.1/32, 192.0.2.1/24 |
| legitimate | eth1 | 10.1.11.1/30 |
| isp | lo | 10.0.0.2/32 |
| isp | eth1 | 10.1.11.2/30 |
| isp | eth2 | 10.1.12.1/30 |
| isp | eth3 | 10.1.13.1/30 |
| hijacker | lo | 10.0.0.3/32 |
| hijacker | eth1 | 10.1.12.2/30 |
| victim | lo | 10.0.0.4/32 |
| victim | eth1 | 10.1.13.2/30 |

## Deploy

```bash
sudo containerlab deploy -t topology.yml
```

## Tasks

### Task 1 — Establish BGP sessions

Configure eBGP on all four nodes. Each node peers only with isp. See the TODO comments in each frr.conf for the full config stubs.

Verify all sessions are Established:
```
show bgp summary
```

### Task 2 — Legitimate advertisement

On `legitimate`, advertise 192.0.2.0/24. Verify victim receives it:
```bash
# On victim:
show bgp ipv4 unicast 192.0.2.0/24
```

Expected AS-path: `65100 65001`

### Task 3 — Simulate a route hijack (same prefix)

On `hijacker`, advertise 192.0.2.0/24.

On victim, check the BGP table:
```
show bgp ipv4 unicast 192.0.2.0/24
```

BGP will now have two paths. The best path is selected by:
1. Shorter AS-path length (both are 2 hops: 65100 65001 vs 65100 65002)
2. Lower router-id (tiebreaker — whoever has the lower BGP router-id wins)

The victim may now be routing 192.0.2.0/24 traffic toward the hijacker.

### Task 4 — More-specific hijack

On `hijacker`, additionally advertise 192.0.2.128/25 (a more-specific prefix).

BGP always prefers the most specific match. The victim will now forward
traffic for 192.0.2.128/25 to the hijacker, regardless of AS-path.

This is how real-world hijacks often work — a more-specific announcement
overrides the legitimate route for part of the address space.

Check victim routing table:
```
show ip route 192.0.2.128
```

### Task 5 — Fix 1: max-prefix limit

Protect isp from accepting too many routes from hijacker.
Apply on isp, in the BGP config for the hijacker neighbor:
```
router bgp 65100
 address-family ipv4 unicast
  neighbor 10.1.12.2 maximum-prefix 5
```

If hijacker sends more than 5 prefixes, the session is torn down.
This protects against route table flooding attacks.

### Task 6 — Fix 2: prefix-list (whitelist)

The correct fix: only accept prefixes that hijacker is legitimately allowed to announce.
Apply on isp, incoming from hijacker:

```
ip prefix-list HIJACKER-IN seq 5 deny 192.0.2.0/24 le 32
ip prefix-list HIJACKER-IN seq 10 permit 0.0.0.0/0 le 32

router bgp 65100
 address-family ipv4 unicast
  neighbor 10.1.12.2 prefix-list HIJACKER-IN in
```

The `le 32` on the deny line catches 192.0.2.0/24 and all more-specifics.

After applying, soft-reset the session:
```
clear bgp 10.1.12.2 soft in
```

Verify on victim — the hijacked route should be gone:
```
show bgp ipv4 unicast 192.0.2.0/24
show bgp ipv4 unicast 192.0.2.128/25
```

### Task 7 — Conceptual: RPKI

RPKI (Resource Public Key Infrastructure) provides cryptographic attestation of who owns which prefixes.

**ROA (Route Origin Authorization)**: a signed record saying "AS65001 is authorized to originate 192.0.2.0/24".

When an RPKI validator is in place:
- Routes with a valid ROA are marked `valid`
- Routes with no ROA are marked `not found`
- Routes where the origin AS doesn't match the ROA are marked `invalid`

Most ISPs drop `invalid` routes. This would have blocked hijacker's advertisement.

FRR supports RPKI via the `rpki` module and connection to a validator (e.g. Routinator, OctoRPKI).

## Key Concepts

### BGP has no built-in prefix ownership authentication

Any router can originate any prefix. BGP was designed for trusted networks — it has no cryptographic proof of who owns what.

### Route selection relevant to hijacking

1. Longest prefix match (more-specific always wins)
2. Shortest AS-path
3. Lowest MED
4. eBGP over iBGP
5. Lowest router-id (tiebreaker)

### Defenses

| Defense | What it does | Limitation |
|---------|-------------|------------|
| Prefix-list | Whitelist valid prefixes per peer | Must maintain per-peer lists manually |
| max-prefix | Disconnect session on too many routes | Stops flooding, not targeted hijacks |
| IRR filtering | Build prefix-lists from routing registry data | IRR data often stale or incomplete |
| RPKI | Cryptographic prefix ownership | Requires validator deployment; partial adoption |
| BGPsec | Signs AS-path too | Not widely deployed |

## Useful Commands

```
show bgp ipv4 unicast                    # full BGP table
show bgp ipv4 unicast 192.0.2.0/24      # paths for specific prefix
show bgp neighbors 10.1.12.2            # neighbor detail
show ip prefix-list                      # defined prefix-lists
show bgp neighbors 10.1.12.2 received-routes   # what peer sent before filter
show bgp neighbors 10.1.12.2 routes            # what peer sent after filter
```

## Destroy

```bash
sudo containerlab destroy -t topology.yml
```
