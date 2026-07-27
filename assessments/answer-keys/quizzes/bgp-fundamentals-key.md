# Answer Key — BGP Fundamentals Topic Quiz

**Total:** 30 points

## A1 — What changes at each kind of boundary? (3 points)

- eBGP normally prepends the advertising router's AS to the AS path and rewrites the
  next hop to itself. (1)
- iBGP carries the AS path without adding the local AS and normally preserves the
  existing next hop; the receiving router must be able to resolve it. (1)
- A route learned from one iBGP peer is not advertised to another iBGP peer. This iBGP
  split-horizon rule requires a full mesh, route reflectors, or confederations for scale.
  (1)

Accept a qualified answer noting policy or `next-hop-self` exceptions. Do not accept
“iBGP does not advertise routes” without the learned-from-iBGP qualification.

## A2 — Attribute scope matters (3 points)

- **Weight:** one router's private preference; not transmitted to any peer.
- **Local preference:** distributed inside the AS and used to select the outbound exit;
  commonly set inbound at the edge.
- **AS-path prepending:** applied outbound to an advertisement to make a remote AS less
  likely to enter through that path.
- **MED:** an outbound suggestion about entry, normally compared only among paths learned
  from the same neighboring AS.

Award 0.5 for each correct scope and 1 for identifying weight as nontransitive. A
candidate who says local preference directly controls the remote AS's inbound decision
has reversed the viewpoint.

## B1 — IPv4 works; IPv6 does not (8 points)

1. r3 has the NLRI but cannot resolve IPv6 next hop `2001:db8:12::1`, so the path cannot
   become a usable installed route. BGP session reachability does not supply data-plane
   reachability to a next hop from another link. (2)
2. MP-BGP carries reachability and next-hop information in address-family-specific
   attributes; the TCP transport address does not have to be the same family as the
   NLRI. r2 learned the IPv6 next hop from eBGP, then iBGP preserved it by default. (2)
3. Under r2's `address-family ipv6`, add:

   ```text
   neighbor 10.1.23.2 next-hop-self
   ```

   The existing command is scoped to the IPv4 address family. Activation, policy, and
   next-hop handling are independent per AF. (2)
4. BGP check: r3 shows the route as best/usable with r2 as the reachable IPv6 next hop.
   Data-plane check: a source-specific IPv6 ping or traceroute from r3 to the advertised
   prefix succeeds with return traffic. One of each is required. (2)

## C1 — Dual-stack border and iBGP handoff (10 points)

```text
router bgp 65002
   router-id 10.0.0.2
   neighbor 10.1.12.1 remote-as 65001
   neighbor 10.1.23.2 remote-as 65002
   address-family ipv4
      neighbor 10.1.12.1 activate
      neighbor 10.1.23.2 activate
      neighbor 10.1.23.2 next-hop-self
      network 10.0.0.2/32
   address-family ipv6
      neighbor 10.1.12.1 activate
      neighbor 10.1.23.2 activate
      neighbor 10.1.23.2 next-hop-self
      network 2001:db8::2/128
```

Point allocation:

- process, local AS, and router ID: 1
- both neighbor definitions and correct remote AS values: 2
- both neighbors activated under IPv4: 1.5
- both neighbors activated under IPv6: 1.5
- `next-hop-self` only toward the iBGP neighbor in IPv4: 1
- `next-hop-self` only toward the iBGP neighbor in IPv6: 1
- each network statement in the correct AF: 2

Defining the same IPv4 neighbor for both AFs is intentional: the extended-next-hop
capability lets the session carry IPv6 NLRI and an IPv6 next hop.

## D1 — Different preferred directions (6 points)

1. To prefer ISP-B for outbound traffic, set higher local preference on routes learned
   **inbound from ISP-B**, and propagate it through iBGP. To ask remote networks to enter
   through ISP-A, prepend the enterprise AS on advertisements sent **outbound to ISP-B**.
   This leaves ISP-A's advertisement shorter. Correct attributes, interfaces/directions,
   and viewpoints earn 3 points. (3)
2. Remote ASes run their own best-path calculations and may set local preference before
   considering path length. The enterprise cannot force their decision with a
   discretionary attribute. (1)
3. When ISP-A fails, its advertisements withdraw and inbound traffic should converge to
   the prepended ISP-B path; outbound traffic already prefers B. When A returns, remote
   networks may move back after BGP convergence, subject to their policies. Verify with
   an external looking glass, route collector, or controlled probe from outside the
   enterprise—not only a local BGP view. (2)

## Remediation table

| Question | Objective | Labs |
|---|---|---|
| A1 | eBGP/iBGP propagation, next hop, iBGP split horizon | `bgp-basics`, `debug-bgp-basics` |
| A2, D1 | Attribute order, scope, and traffic-engineering direction | `bgp-path-selection`, `debug-bgp-path-selection` |
| B1 | MP-BGP transport independence and per-AF next-hop handling | `ipv6-bgp`, `bgp-basics` |
| C1 | EOS eBGP/iBGP and dual-stack address-family configuration | `bgp-basics`, `ipv6-bgp` |
