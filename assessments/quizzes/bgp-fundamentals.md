# Topic Quiz — BGP Fundamentals

**Time:** 35 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `bgp-basics`, `bgp-path-selection`, and `ipv6-bgp`. The guided BGP
basics and path-selection debug labs are recommended.

Configuration syntax is Arista EOS as used by the labs.

---

## Section 1 — Mechanisms (6 points)

### A1 — What changes at each kind of boundary? (3 points)

Contrast advertising a route to an eBGP neighbor with advertising it to an iBGP
neighbor. Address the AS path, the next-hop attribute, and the iBGP rule that prevents a
route learned from one iBGP peer from being advertised to another. (3 pts)

### A2 — Attribute scope matters (3 points)

For weight, local preference, AS-path prepending, and MED, state whether each primarily
controls one router, outbound exit choice across an AS, or how another AS may enter.
Then identify which of the four is not transmitted to any neighbor. (3 pts)

---

## Section 2 — Evidence reading (8 points)

### B1 — IPv4 works; IPv6 does not

r2 and r3 are iBGP peers in AS 65002 using IPv4 transport. Both address families are
negotiated. r2 learns `2001:db8:100::/64` from an eBGP neighbor.

```text
r3# show bgp ipv6 unicast 2001:db8:100::/64
BGP routing table entry for 2001:db8:100::/64
 Paths: 1 available
  65001
    2001:db8:12::1 from 10.1.23.1 (10.0.0.2)
      Origin IGP, localpref 100, internal, not best: next hop inaccessible

r3# show ipv6 route 2001:db8:12::1
% Network not in table

r2# show running-config section router bgp
router bgp 65002
   neighbor 10.1.23.2 remote-as 65002
   address-family ipv4
      neighbor 10.1.23.2 activate
      neighbor 10.1.23.2 next-hop-self
   address-family ipv6
      neighbor 10.1.23.2 activate
```

1. Why is the prefix present in BGP but unusable for forwarding on r3? (2 pts)
2. Explain how an IPv4-transport session can carry an IPv6 next hop and why iBGP left
   that next hop unchanged. (2 pts)
3. Give the exact configuration repair and explain why the IPv4 command already present
   did not cover IPv6. (2 pts)
4. Give one BGP-table check and one IPv6 data-plane check after the repair. (2 pts)

---

## Section 3 — Application (10 points)

### C1 — Dual-stack border and iBGP handoff

Configure r2 with:

- local AS 65002 and router ID `10.0.0.2`;
- eBGP neighbor r1 at `10.1.12.1`, AS 65001;
- iBGP neighbor r3 at `10.1.23.2`, AS 65002;
- both neighbors activated for IPv4 and IPv6 unicast over those IPv4 sessions;
- `next-hop-self` toward r3 in both address families;
- IPv4 loopback `10.0.0.2/32` and IPv6 loopback `2001:db8::2/128` advertised in their
  respective families.

Write the complete EOS BGP configuration. Interfaces and reachability to neighbor
addresses already exist.

---

## Section 4 — Design and troubleshooting (6 points)

### D1 — Different preferred directions

An enterprise connects to ISP-A and ISP-B. It wants ordinary outbound traffic to prefer
ISP-B, while asking the internet to prefer ISP-A when reaching the enterprise prefix.
Both links must remain usable as backups.

1. Choose one BGP attribute for each direction, including where and in which direction
   the policy is applied. (3 pts)
2. Explain why the inbound preference is only a request, not a guarantee. (1 pt)
3. Describe the expected path behavior when ISP-A fails and when it returns. Include one
   verification that tests the externally visible path rather than only the enterprise
   router's BGP table. (2 pts)

---

*End of BGP Fundamentals quiz. Key:
[`../answer-keys/quizzes/bgp-fundamentals-key.md`](../answer-keys/quizzes/bgp-fundamentals-key.md).*
