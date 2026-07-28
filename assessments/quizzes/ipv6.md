# Topic Quiz — IPv6 and Dual-Stack Operations

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `ipv6-access-services`, `ipv6-ospf3`, `ipv6-bgp`,
`ipv6-transition`, and `enterprise-dual-stack-capstone`.

## Section 1 — Mechanisms (6 points)

### A1 — Host configuration is not one protocol (3 points)

A client has a global SLAAC address but no default route and cannot resolve names.
Explain separately how it normally learns:

1. an on-link prefix and address parameters;
2. a default router; and
3. recursive DNS information.

State why DHCPv6 alone is not a substitute for every Router Advertisement function.
(3 pts)

### A2 — IPv6 routing control planes (3 points)

1. Why do OSPFv3 neighbors and route next hops commonly use link-local addresses even
   when global addresses exist? (1 pt)
2. Which OSPFv3 LSAs carry topology, link-local information, and intra-area prefixes?
   (1 pt)
3. How can an IPv4-transport BGP session carry IPv6 NLRI and an IPv6 next hop? (1 pt)

## Section 2 — Evidence reading (8 points)

### B1 — One session, one broken family

`edge1` and `core1` share one MP-BGP session over IPv4. IPv4 service works.

```text
edge1# show bgp ipv6 unicast summary
Neighbor       State  PfxRcd
10.10.12.2     Estab       8

edge1# show bgp ipv6 unicast 2001:db8:200::/48
*> 2001:db8:200::/48  2001:db8:12::2

edge1# show ipv6 route 2001:db8:200::/48
% Network not in table

edge1# show ipv6 route 2001:db8:12::2
% Network not in table
```

1. Explain why Established plus `PfxRcd 8` does not prove usable IPv6 forwarding.
   (2 pts)
2. Identify the immediate route-installation failure. (2 pts)
3. Give two likely per-address-family configuration causes. (2 pts)
4. Give a control-plane and end-to-end verification sequence after repair. (2 pts)

## Section 3 — Application (10 points)

### C1 — Select a coexistence design

Choose and justify the most appropriate approach for each requirement:

1. A campus can run both protocols end to end while applications migrate gradually.
   (2 pts)
2. IPv6-only clients must reach an unchanged IPv4-only public service. (3 pts)
3. Dual-stack provider edges must carry customer IPv6 across an IPv4-only MPLS core
   without teaching the core IPv6 routes. (3 pts)
4. A guest policy blocks an internal application over IPv4 but IPv6 still succeeds.
   State the required correction. (2 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Renumber without an outage

A site must move from `2001:db8:100::/48` to `2001:db8:300::/48`. Describe the
overlap, Router Advertisement lifetime, DNS, routing, policy, and application checks
needed to retire the old prefix without using “disable IPv6” or deleting AAAA records as
a workaround. (6 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/ipv6-key.md`](../answer-keys/quizzes/ipv6-key.md).*
