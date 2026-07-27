# Topic Quiz — EIGRP

**Time:** 25 minutes · **Total:** 20 points · **Closed book, no CLI**

**Prerequisites:** `eigrp-basics`, `eigrp-variance`, and `eigrp-stub`. The
`debug-eigrp-basics` lab is recommended.

Configuration syntax is FRR 8.4 as used by the labs.

---

## Section 1 — Mechanisms (4 points)

### A1 — What DUAL is protecting

Define feasible distance and reported distance, write the feasibility condition as an
inequality, and explain why promoting a feasible successor is faster and safer than
querying for a new path. (4 pts)

---

## Section 2 — Evidence reading (6 points)

### B1 — Decide before configuring variance

On r1:

```text
r1# show ip eigrp topology all-links
P 10.0.0.4/32, 1 successors, FD is 2816
        via 10.1.12.2 (2816/2560), Ethernet1
        via 10.1.13.2 (4608/2304), Ethernet2
```

No `variance` command is currently configured.

1. Identify the successor and determine whether the other path is a feasible successor.
   Show the comparison that proves it. (2 pts)
2. What is the smallest integer variance that can install the second path? Show the
   metric calculation. (2 pts)
3. After it is installed, why will traffic not be divided 50/50? (1 pt)
4. If the second path's RD rises to 3000 while its total metric stays 4608, can
   `variance 10` install it? Why? (1 pt)

---

## Section 3 — Application (5 points)

### C1 — A stub with a real downstream

Branch router `spoke3` runs EIGRP AS 100. It should advertise its connected and summary
routes, remain a stub, and additionally advertise `10.30.30.0/24`, which it learns from
a downstream EIGRP neighbor and is therefore neither connected nor a local summary.

Write the FRR prefix-list, route-map, and EIGRP stub configuration. The EIGRP process and
network statements already exist.

---

## Section 4 — Troubleshooting (5 points)

### D1 — The hello that cannot become a neighbor

All links are up. r1 has an EIGRP adjacency to r2 but none to r3.

```text
r1# show running-config section router eigrp
router eigrp 100
 network 0.0.0.0/0

r1# show ip eigrp interfaces
EIGRP-IPv4 Interfaces for AS(100)
Interface  Peers
eth1       1
eth2       0

packet capture on eth2:
EIGRP Hello, Autonomous System: 101, K values: 1 0 1 0 0
```

1. State the fault and why r3 never appears as a neighbor. (2 pts)
2. Give the minimal repair. (1 pt)
3. Give one adjacency check and one reachability check after the repair. (1 pt)
4. Name a change that could hide the user symptom without repairing this fault, and
   explain why it is unacceptable. (1 pt)

---

*End of EIGRP quiz. Key: [`../answer-keys/quizzes/eigrp-key.md`](../answer-keys/quizzes/eigrp-key.md).*
