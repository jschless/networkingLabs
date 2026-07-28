# Topic Quiz — Hybrid Cloud Networking

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `cloud-hybrid-networking`.

## Section 1 — Mechanisms (6 points)

### A1 — Learned route versus associated path (3 points)

Explain why a transit hub learning a workload prefix through BGP does not prove that the
workload's return traffic uses the required inspection path. Distinguish route
propagation, route-table association, and source-policy lookup. (3 pts)

### A2 — Two policy layers (3 points)

Contrast a stateful inspection policy with a stateless subnet ACL. Explain the required
reverse-flow treatment and what counters should change during one permitted HTTPS
transaction. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — The SYN arrives, but inspection never sees the reply

```text
corporate DNS: api.private.example -> 10.81.10.10
inspection capture toward App A: corporate SYN forwarded to 10.81.10.10
App A table 201 route-get from 10.81.10.10 to 10.80.10.10:
    via 10.80.100.1 dev direct-transit table 201
inspection established/related counter: 0
```

1. Explain which components are working. (2 pts)
2. Identify the broken association and why a stateful firewall rejects or misses the
   flow. (2 pts)
3. Give the smallest repair. (2 pts)
4. Give two checks that prove path intent, not only application reachability. (2 pts)

## Section 3 — Application (10 points)

### C1 — Design a redundant inspected hybrid path

Design two on-premises attachments to a transit domain with:

- deterministic primary/backup selection;
- propagation of only approved corporate and application prefixes;
- symmetric inspection for private HTTPS;
- private DNS visible only to trusted sources; and
- a new-session failover test.

State which evidence belongs at the edge, transit, inspection, DNS, and application
route-table boundaries. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — An acquisition brings overlapping space

An acquired cloud domain uses the same `10.80.10.0/24` as the corporate LAN. Explain
why advertising it into shared transit is unsafe, compare renumbering, non-transitive
isolation, and scoped translation, and give a verification plan for the selected
response. (6 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/hybrid-cloud-key.md`](../answer-keys/quizzes/hybrid-cloud-key.md).*
