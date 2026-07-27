# Answer Key — High Availability

**Total:** 30 points

## A1 — Fast failure versus protocol timers (3 points)

BFD is a protocol-independent forwarding-path liveness session with short intervals,
rather than waiting for routing-protocol hello/hold expiry. Echo mode tests a packet
looped through the peer's forwarding plane, not only asynchronous control packets.
Aggressive timers in contended containers can miss scheduling deadlines and create false
failures. (3)

## A2 — Address ownership is not path health (3 points)

Highest VRRP priority becomes master; preemption lets a recovered higher-priority router
retake the role. Tracking decrements priority when an uplink fails. Without it, the
master can keep answering for the VIP while having no usable upstream path, attracting
and black-holing host traffic instead of yielding to the healthy backup. (3)

## B1 — The VIP moved; the flow died (8 points)

Address failover works, but fw2 never received the established connection state.
Successful new flows create local conntrack entries and therefore do not test state
continuity. conntrackd must replicate active state to fw2's external cache, and the
promotion hook must commit that cache into the kernel table. `tcp_loose=1` lets the new
firewall infer/adopt traffic it never saw begin, weakening strict state enforcement and
hiding missing replication. Before retest, confirm the live flow appears in
`conntrackd -e` on standby and verify keepalived's primary notification invokes the
commit action. (3+2+1+2)

## C1 — Gateway priority follows usable uplinks (10 points)

```text
track 1 interface Ethernet4 line-protocol
track 2 interface Ethernet5 line-protocol

interface Vlan10
   vrrp 10 ip 192.168.10.254
   vrrp 10 priority 120
   vrrp 10 preempt
   vrrp 10 preempt delay minimum 30
   vrrp 10 track 1 decrement 30
   vrrp 10 track 2 decrement 30
```

Award 2 for tracks, 2 for VRID/VIP, 2 for priority/preemption, 2 for delayed preemption,
and 2 for decrements plus calculation. With both down: `120 - 30 - 30 = 60`, below the
backup's 100, so dist1 yields.

## D1 — BFD and Graceful Restart pull differently (6 points)

GR asks helpers to retain the restarting peer's routes as stale while its control plane
returns, assuming forwarding continues. A real crash may invalidate that assumption and
black-hole traffic until stale timers expire. Aggressive BFD can declare the peer failed
and withdraw routes before GR provides continuity. For maintenance, confirm negotiated
GR/helper capability, choose bounded restart/stalepath timers, coordinate or relax BFD
for the window, run continuous source-specific traffic, restart only the process, verify
stale retention and recovery, then test a true forwarding failure separately to ensure
rapid withdrawal. (2+1+3)

## Remediation table

| Question | Labs |
|---|---|
| A1 | `bfd-ospf`, `bfd-bgp` |
| A2, C1 | `vrrp`, `ha-network-design-ceos` |
| B1 | `service-ha` |
| D1 | `graceful-restart`, `bfd-bgp` |
