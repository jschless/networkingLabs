# Answer Key — EIGRP Topic Quiz

**Total:** 20 points

## A1 — What DUAL is protecting (4 points)

- Feasible distance is the best known total metric from the local router to the
  destination. (1)
- Reported distance is the metric a neighbor reports from itself to that destination.
  (1)
- A candidate is a feasible successor when `neighbor RD < current successor FD`. (1)
- Because the neighbor claims to be closer than the local router's current best distance,
  it cannot be routing back through the local router. DUAL can promote that precomputed,
  loop-free path immediately; without one it must go active and query before selecting a
  replacement. (1)

Do not award the last point for only “it converges faster”; the prevalidated loop-free
property and avoided query are the mechanism.

## B1 — Decide before configuring variance (6 points)

1. The successor is via `10.1.12.2`, with total metric 2816. The second path is feasible
   because its RD 2304 is less than the current FD 2816. (2)
2. `4608 / 2816` is greater than 1 and less than 2, so the smallest integer is
   `variance 2`. Equivalently, show `4608 <= 2 × 2816 = 5632`. (2)
3. EIGRP shares traffic inversely proportional to metric; the 2816 path receives more
   traffic than the 4608 path. (1)
4. No. With RD 3000, `3000 < 2816` is false. Variance never overrides the feasibility
   condition, regardless of its value. (1)

**Misconception:** `all-links` displays paths that the ordinary topology view can hide;
it does not make every displayed path eligible for variance.

## C1 — A stub with a real downstream (5 points)

```text
ip prefix-list CE-DOWNSTREAM permit 10.30.30.0/24

route-map LEAK-CE permit 10
 match ip address prefix-list CE-DOWNSTREAM

router eigrp 100
 eigrp stub connected summary leak-map LEAK-CE
```

- exact prefix-list match: 1
- route-map permit sequence: 1
- route-map matches the prefix-list: 1
- stub retains connected and summary advertisements: 1
- leak-map attached to the stub command: 1

Equivalent names earn full credit. A plain redistribution command does not: it neither
expresses the stub exception nor preserves the query-boundary intent.

## D1 — The hello that cannot become a neighbor (5 points)

1. r3 is sending Hellos for AS 101 while r1 runs AS 100. EIGRP neighbors must agree on
   the autonomous-system/process number, so r1 rejects the Hello and never creates a
   neighbor entry. (2)
2. Put r3 in EIGRP AS 100, preserving its intended network and passive-interface
   statements; remove the erroneous AS 101 process if necessary. (1)
3. Check that r3 appears in `show ip eigrp neighbors`, then test a route and end-to-end
   ping to a prefix learned through r3. Both kinds of check are required. (1)
4. Acceptable examples include adding a static route around r3, moving the affected
   prefix to r2, or changing r1 to AS 101 while breaking r2. These can restore one symptom
   or move the outage but do not repair the intended adjacency and may create hidden,
   nonconvergent state. (1)

## Remediation table

| Question | Objective | Labs |
|---|---|---|
| A1 | FD, RD, feasibility, successor promotion, queries | `eigrp-basics` |
| B1 | Variance eligibility and unequal traffic sharing | `eigrp-variance` |
| C1 | Stub query boundaries and leak-map exceptions | `eigrp-stub` |
| D1 | Neighbor admission and AS mismatch | `debug-eigrp-basics`, `eigrp-basics` |
