# Topic Quiz — BGP Labeled Unicast

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `bgp-labeled-unicast`.

## Section 1 — Mechanisms (6 points)

### A1 — Signal a labeled prefix (3 points)

Explain what the IPv4 labeled-unicast address family adds to ordinary BGP reachability
and why labels remain locally significant even across an inter-AS LSP. (3 pts)

### A2 — Underlay and session choices (3 points)

Explain why loopback iBGP-LU requires an IGP inside each AS while directly connected
eBGP-LU between ASBRs normally uses link addresses. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — The label stitch disappeared

```text
r2-r3 eBGP session: Established
r2 IPv4 unicast: 10.0.0.4/32 present
r2 IPv4 labeled-unicast: 10.0.0.4/32 absent
r2 LFIB: no entry for the remote PE prefix
r1 ping 10.0.0.4 source 10.0.0.1: fail
```

1. Localize the address-family failure. (3 pts)
2. Give two likely causes. (2 pts)
3. Give three checks proving the repaired labeled path end to end. (3 pts)

## Section 3 — Application (10 points)

### C1 — Trace the label chain

Remote PE `r4` advertises label 17 for its loopback. ASBR `r3` advertises label 28 to
`r2`, and `r2` advertises label 39 to `r1`. Describe the BGP and LFIB state required at
each router and the label operations for traffic from `r1` to `r4`. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Choose inter-AS Option C

Defend or reject BGP-LU/Option C for two providers exchanging many VPN reachability
endpoints. Compare scalability, ASBR state, trust/policy exposure, failure blast radius,
and verification with simpler per-VRF handoffs. (6 pts)

*Key: [`../answer-keys/quizzes/bgp-lu-key.md`](../answer-keys/quizzes/bgp-lu-key.md).*
