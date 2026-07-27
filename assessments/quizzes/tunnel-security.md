# Topic Quiz — GRE, IPsec & MTU

**Time:** 35 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `gre-basics`, `ipsec-basics`, `gre-ipsec`,
`mtu-pmtud-troubleshooting`, and `opnsense-ipsec-nat-t`.

---

## Section 1 — Mechanisms (6 points)

### A1 — Overlay without security (3 points)

State what GRE adds and what it does not provide. Then explain the recursive-routing
failure created when the route to a GRE destination is learned through the GRE tunnel
itself. (3 pts)

### A2 — Read the security layers (3 points)

Distinguish an IKE proposal failure from an ESP/traffic-selector failure using SA state.
Then explain why NAT detection moves IPsec data traffic to UDP/4500. (3 pts)

---

## Section 2 — Evidence reading (8 points)

### B1 — Small packets work

A GRE path crosses a WAN with MTU 1400. The tunnel MTU remains 1500. GRE adds 24 bytes.
Small pings work; a 1400-byte inner IPv4 packet with DF set disappears. ICMP
fragmentation-needed messages are filtered.

1. Calculate the largest inner IP packet that fits without fragmentation. (2 pts)
2. Explain the PMTUD black hole and why ordinary small pings are misleading. (2 pts)
3. Give the tunnel-MTU repair and a safe IPv4 TCP MSS value, showing the arithmetic.
   (2 pts)
4. Give two tests that prove the repaired packet-size boundary. (2 pts)

---

## Section 3 — Application (10 points)

### C1 — Choose the packet stack (6 points)

For each requirement, choose plain GRE, route-based/tunnel-mode IPsec, or GRE protected
by transport-mode IPsec, and justify the packet stack:

1. Carry a routing protocol's multicast packets between sites with confidentiality.
2. Encrypt only two fixed LAN prefixes with no dynamic routing requirement.
3. Build a diagnostic overlay where confidentiality is explicitly unnecessary.

For the first case, identify what the IPsec selectors match and why tunnel-mode IPsec
would add redundant overhead.

### C2 — NAT-T firewall policy (4 points)

One IPsec peer is behind NAT. State the public-side firewall/forwarding requirements for
UDP/500 and UDP/4500, what a healthy capture should show after NAT detection, and the SA
symptom if UDP/4500 alone is blocked.

---

## Section 4 — Troubleshooting method (6 points)

### D1 — Stop at the failed layer

Write an ordered six-step triage for “the site-to-site VPN is down” that distinguishes
underlay reachability, IKE, child-SA/selectors, NAT-T, routing, and end-host forwarding.
Each step must name evidence and what it rules out. (6 pts)

---

*End of GRE, IPsec & MTU quiz. Key:
[`../answer-keys/quizzes/tunnel-security-key.md`](../answer-keys/quizzes/tunnel-security-key.md).*
