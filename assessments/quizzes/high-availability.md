# Topic Quiz — High Availability

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** the High Availability track from BFD through Graceful Restart.

---

## Section 1 — Mechanisms (6 points)

### A1 — Fast failure versus protocol timers (3 points)

Explain why BFD can detect a forwarding failure faster than minimum OSPF/BGP timers, what
echo mode tests, and why extremely aggressive timers are risky in container labs. (3 pts)

### A2 — Address ownership is not path health (3 points)

Explain VRRP priority, preemption, and upstream tracking. Construct the black hole that
occurs when a high-priority master keeps the VIP after losing every uplink. (3 pts)

---

## Section 2 — Evidence reading (8 points)

### B1 — The VIP moved; the flow died

After fw1 fails, fw2 owns both VRRP VIPs. New pings and new TCP sessions work, but a TCP
transfer established before failover stops.

```text
fw2# ip addr show | grep 10.10
10.10.0.1/24
10.10.20.1/24

fw2# conntrack -L | grep 5201
<no output>

fw2# conntrackd -e | grep 5201
<no output>

fw2# sysctl net.netfilter.nf_conntrack_tcp_loose
net.netfilter.nf_conntrack_tcp_loose = 0
```

1. Localize the failure and explain why successful new sessions do not disprove it.
   (3 pts)
2. State the missing HA mechanism and the activation action needed when fw2 becomes
   primary. (2 pts)
3. Explain why setting `tcp_loose=1` masks rather than repairs the design. (1 pt)
4. Give two checks before repeating the live-flow failover test. (2 pts)

---

## Section 3 — Application (10 points)

### C1 — Gateway priority follows usable uplinks

On dist1 `Vlan10`, configure VRRP group 10 with VIP `192.168.10.254`, priority 120,
preemption delayed 30 seconds, and two tracked uplinks:

- track 1 follows `Ethernet4` line protocol;
- track 2 follows `Ethernet5` line protocol;
- each failed track decrements VRRP priority by 30.

Write the EOS configuration and calculate dist1's priority with both uplinks down. The
backup has priority 100.

---

## Section 4 — Design and troubleshooting (6 points)

### D1 — BFD and Graceful Restart pull differently

A BGP route reflector is undergoing a planned process restart. Its peers support
Graceful Restart and aggressive BFD.

1. Explain what GR asks helpers to retain and the risk if the event is a real forwarding
   failure rather than a clean restart. (2 pts)
2. Explain how aggressive BFD can defeat the intended maintenance behavior. (1 pt)
3. Propose a change and verification plan that distinguishes the planned restart from a
   real crash, bounds stale state, and tests forwarding continuity. (3 pts)

---

<!-- site-include-end -->

*End of High Availability quiz. Key:
[`../answer-keys/quizzes/high-availability-key.md`](../answer-keys/quizzes/high-availability-key.md).*
