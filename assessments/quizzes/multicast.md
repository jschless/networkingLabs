# Topic Quiz — Enterprise Multicast

**Time:** 25 minutes · **Total:** 20 points · **Closed book, no CLI**

**Prerequisites:** `enterprise-multicast`.

## Section 1 — Mechanisms (4 points)

### A1 — Build the forwarding state (4 points)

State the distinct job performed by each component:

1. IGMP at the receiver edge;
2. PIM between routers;
3. the rendezvous point in PIM sparse mode; and
4. the multicast routing entry and its RPF interface.

(4 pts)

## Section 2 — Evidence reading (6 points)

### B1 — Local receivers work, remote receivers fail

A source and one receiver share VLAN 20 behind `dist1`. A second receiver is behind
`dist3`. Unicast works everywhere.

```text
dist3# show ip igmp groups
239.50.1.1  Vlan30

dist3# show ip pim neighbor
10.0.23.2  Ethernet1  Up

dist3# show ip mroute 239.50.1.1
(*, 239.50.1.1), RP 10.255.0.1, RPF nbr 0.0.0.0, Incoming interface: Null

dist3# show ip route 10.255.0.1
% Network not in table
```

1. Identify what is healthy and what is broken. (3 pts)
2. Explain why the same-VLAN receiver can continue receiving. (1 pt)
3. Give the minimal repair and two state checks that prove remote recovery. (2 pts)

## Section 3 — Application (5 points)

### C1 — Remove the single-RP dependency

Design an RP-redundancy approach for two campus cores. State how routers discover or
select the RP, what address/state must survive a core failure, and what remains dependent
on healthy unicast routing. (5 pts)

## Section 4 — Design and troubleshooting (5 points)

### D1 — Trace a missing multicast flow

Starting from a remote receiver that sees no UDP stream, give an ordered five-step
evidence method that distinguishes missing receiver membership, a broken PIM hop, an RPF
failure, missing RP state, and an application/source problem. (5 pts)

*Key: [`../answer-keys/quizzes/multicast-key.md`](../answer-keys/quizzes/multicast-key.md).*
