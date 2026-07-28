# Topic Quiz — IS-IS

**Time:** 25 minutes · **Total:** 20 points · **Closed book, no CLI**

**Prerequisites:** `isis-basics` and `isis-multiarea`. The `debug-isis-basics` lab is
recommended.

Configuration syntax is Arista EOS as used by the labs.

---

## Section 1 — Mechanisms (4 points)

### A1 — Identity in the NET (2 points)

Break `49.0007.0100.0000.0012.00` into its area address, system ID, and NSEL. Which part
must be unique to the router, and what breaks when two routers duplicate it?

### A2 — Leaving a Level-1 area (2 points)

An L1 router has no leaked specifics for a remote area. Explain how it still chooses a
way out, including the bit that drives the behavior and the type of route installed.
Then state what route leaking adds.

---

## Section 2 — Evidence reading (6 points)

### B1 — Default versus detail

r1 is Level-1-only. r2 is Level-1-2 and connects area `0001` to the Level-2 backbone.

```text
r1# show ip route isis
I L1  10.0.0.2/32 [115/10] via 10.1.12.2, Ethernet1
I L1  0.0.0.0/0   [115/10] via 10.1.12.2, Ethernet1

r1# show isis database level-1 detail
LSPID                 ATT
0100.0000.0001.00-00   0
0100.0000.0002.00-00   1

r2# show isis database level-2 detail | include 10.44.44.44
  IP Reachability: 10.44.44.44/32
```

1. Why does r1 have a default through r2 even though no default was manually originated?
   (2 pts)
2. Is the absence of `10.44.44.44/32` as a specific L1 route evidence of a fault? Why?
   (1 pt)
3. What control on r2 would make that specific prefix appear in r1's L1 database and
   route table? Include the safety mechanism that should constrain it. (2 pts)
4. Give one scalability trade-off of adding many leaked specifics. (1 pt)

---

## Section 3 — Application (5 points)

### C1 — An L1/L2 boundary router

Configure EOS router r2 for IS-IS process `CORE`:

- NET `49.0001.0100.0000.0002.00`
- Level-1-2 operation
- `Loopback0`, `Ethernet1`, and `Ethernet2` participate in IS-IS
- `Loopback0` is passive

Addresses already exist. Write the process and interface configuration.

---

## Section 4 — Troubleshooting (5 points)

### D1 — Same link, different areas

r7 and r8 are intended to form a Level-1 adjacency on an Ethernet link. The link and IP
addressing are healthy.

```text
r7# show isis summary
IS-IS Instance: CORE
System ID: 0100.0000.0007
NET: 49.0001.0100.0000.0007.00
IS-Type: level-1

r8# show isis summary
IS-IS Instance: CORE
System ID: 0100.0000.0008
NET: 49.0002.0100.0000.0008.00
IS-Type: level-1
```

1. State the fault and why the Level-1 adjacency cannot form. (2 pts)
2. Why would an area-address mismatch not, by itself, prevent a Level-2 adjacency between
   two Level-2-capable routers? (1 pt)
3. Give the minimal repair and two checks that prove full recovery. (2 pts)

---

<!-- site-include-end -->

*End of IS-IS quiz. Key: [`../answer-keys/quizzes/isis-key.md`](../answer-keys/quizzes/isis-key.md).*
