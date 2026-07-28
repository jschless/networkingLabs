# Topic Quiz — Application Delivery

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `load-balancer-basics`, `service-ha`, `anycast-dns`, and
`global-application-delivery`.

## Section 1 — Mechanisms (6 points)

### A1 — L4, L7, and client identity (3 points)

Compare an L4 proxy and an L7 HTTP proxy in terms of what they can inspect, where client
connections terminate, and how a backend can recover the original client identity.
(3 pts)

### A2 — Three different health decisions (3 points)

Distinguish backend pool health, site/GSLB health, and DNS resolver caching. Explain why
all three can temporarily disagree during a failure. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — The green site that disappeared

Near-site users receive the remote site's address. Evidence shows:

```text
site-a HAProxy stats: a-app1 UP/L7OK, a-app2 UP/L7OK
direct site-a request: HTTP 200
GSLB health log: site_a=DOWN code=403 source=10.220.30.53
authoritative DNS: near-a.example.test -> 198.51.100.20
```

1. Localize the failed boundary and explain why the green backend pool does not
   contradict the GSLB result. (3 pts)
2. Give the most likely policy class causing the symptom. (2 pts)
3. Describe a minimal repair and three checks that prove both healthy withdrawal and
   healthy publication still work. (3 pts)

## Section 3 — Application (10 points)

### C1 — Drain an origin without surprising users

A cookie-persistent pool has `app1` and `app2`. `app1` needs maintenance, and `/assets/`
is cached at an edge proxy.

Design the drain and verification procedure. Account for new sessions, existing
persistent sessions, active connections, cache hits, health state, and the final return
to service. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Measure a site-failure timeline

The GSLB probe interval is 2 seconds, failure threshold is 2, authoritative reload can
take 1 second, and DNS TTL is 12 seconds. A recursive resolver was primed one second
before site A failed.

Describe the order—not a falsely exact single outage time—in which site health,
authoritative DNS, the recursive answer, and new client connections change. Include the
fate of an already-established TCP session and the evidence needed to measure each
boundary. (6 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/application-delivery-key.md`](../answer-keys/quizzes/application-delivery-key.md).*
