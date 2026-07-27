# Answer Key — Application Delivery Topic Quiz

**Total:** 30 points

## A1 — L4, L7, and client identity (3 points)

- An L4 proxy selects and relays using transport information but cannot make HTTP
  path/header decisions without terminating and parsing the application protocol. (1)
- A conventional L4 or L7 proxy terminates the client connection and opens a separate
  backend connection, so the backend normally sees the proxy's source address. (1)
- An HTTP-aware proxy can add a trusted `X-Forwarded-For` or standardized `Forwarded`
  header. The backend must trust it only from controlled proxies; TLS must be terminated
  where HTTP headers are inspected or changed. (1)

## A2 — Three different health decisions (3 points)

- Pool health decides whether a particular origin receives work from its local load
  balancer. (1)
- Site/GSLB health decides whether the site's application path should be published to new
  DNS clients; its probe source and policy path can differ from local pool checks. (1)
- A recursive resolver can continue returning a previously cached answer until TTL
  expiry even after authoritative publication changes. Probe intervals, thresholds,
  controller reload, and caching therefore create distinct transition times. (1)

## B1 — The green site that disappeared (8 points)

1. The failure is on the GSLB application's source-specific probe/policy path, after the
   local pool decision. Local HAProxy can see both origins as healthy while the separate
   GSLB probe receives a policy-generated 403 and correctly withdraws the site. (3)
2. The likely cause is an ACL/firewall/WAF or frontend rule that denies `/health` or the
   GSLB source address, not failed origins. (2)
3. Remove or narrow only the erroneous probe-path rule. Then verify: the same
   source-bound GSLB request receives HTTP 200; authoritative DNS republishes site A
   while healthy; and a real application failure still makes the local/GSLB health
   transition and withdraws site A before it is restored. (3)

**Misconception:** Forcing the DNS record to site A masks the health-policy fault and
breaks genuine failure withdrawal.

## C1 — Drain an origin without surprising users (10 points)

- Validate current pool health, capacity on `app2`, persistence behavior, active
  connections, and cache state before changing anything. (2)
- Put `app1` into administrative drain so it receives no new assignments; do not confuse
  drain with immediately killing all established connections. (2)
- Test with a fresh cookie jar to prove new sessions select `app2`, and with an existing
  cookie/connection to observe the platform's defined persistence and drain behavior.
  (2)
- Watch active sessions reach zero or a declared timeout before stopping `app1`; confirm
  the remaining origin can sustain load. (1)
- Treat edge-cache HITs separately: they may create no new origin request and can serve
  content until expiry or purge, so use a cache bypass/MISS or request ID when validating
  origin behavior. (2)
- After maintenance, pass the real application health check, return `app1` to ready,
  verify gradual new assignment and both origin identities, then continue monitoring.
  (1)

## D1 — Measure a site-failure timeline (6 points)

- The health controller can declare the site down only after the failed probes meet the
  threshold—nominally around four seconds here, with scheduling and timeout variation.
  (1)
- Authoritative DNS changes after that decision and its reload delay, not at the instant
  the site process fails. Observe probe logs and direct authoritative queries. (1)
- The already-primed recursive resolver can retain site A for up to its remaining
  11-second TTL, subject to resolver behavior. Observe repeated resolver queries without
  flushing its cache. (1)
- New connections using the cached answer continue targeting site A until the resolver
  refreshes; after refresh they target the surviving site. Correlate DNS answer, target
  address, TLS, and request result. (1)
- An established TCP session does not migrate merely because DNS changes. It survives
  only if the old endpoint/path and state survive; otherwise it fails and a later
  reconnect uses the then-current resolution. (1)
- Full credit requires a timestamped timeline from health logs, authoritative and
  recursive DNS observations, and client connection/request evidence rather than adding
  the nominal timers into one guaranteed outage number. (1)

## Remediation

| Weak area | Review |
|---|---|
| L4/L7 proxying, health checks, client identity, and return paths | `labs/load-balancer-basics/` |
| Stateful service failover and connection survival | `labs/service-ha/` |
| Route health tied to service health | `labs/anycast-dns/` |
| GSLB, persistence, draining, caching, and failure timelines | `labs/global-application-delivery/` |
