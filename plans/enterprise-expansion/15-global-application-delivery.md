# WP-15 — Global Application Delivery and Edge Services

## Outcome

Build `labs/global-application-delivery/`, a practice lab that evolves the existing
HAProxy and anycast-DNS foundations into a two-site service: authoritative health-
aware DNS/GSLB behavior, site-local load balancing, TLS/SNI, persistence, WAF seam,
cache/CDN concepts, failure withdrawal, and client-visible DNS caching effects.

Target coverage: level 4.

## Fidelity

Live:

- two application sites with local L4/L7 load balancers and multiple backends;
- health checks at transport and application layers;
- DNS-based site selection/withdrawal with controlled TTL;
- optional anycast authoritative/resolver service if it improves the comparison;
- TLS/SNI/certificate selection and upstream identity;
- persistence/cookie/source behavior and safe draining;
- reverse-proxy/WAF path and origin protection;
- cache behavior, stale data and cache purge in a local edge-cache analogue;
- site/link/backend failure with measured client effects.

Conceptual mapping: commercial GSLB/CDN/edge network, global anycast underlay,
provider health APIs, DDoS scrubbing, geo/latency routing and internet-scale cache.

## Feature-probe gate

1. Pin HAProxy/nginx/Envoy and CoreDNS/PowerDNS-compatible components.
2. Prove DNS health state can be driven deterministically by real site probes.
3. Prove resolver/client cache behavior with TTLs in a bounded test harness.
4. Prove TLS/SNI and WAF safe rules do not require external certificate services.
5. Prove site withdrawal/restore and connection draining are observable and reset cleanly.

## Lab type and platform

- Type: practice.
- Linux nodes: `gslb`, `resolver`, `site-a-lb`, `site-b-lb`, four backends,
  `edge-cache`, `client-near-a`, `client-near-b`, `observer`.
- Optional cEOS routers only if path/anycast comparison needs them and resource probe
  justifies them; this is an application-delivery lab, not another routing lab.

## Topology/addressing

```text
 client-a -- resolver/gslb -- site-a-lb -- a-app1/a-app2
       \                       |
        \-- edge-cache --------+
 client-b ------------------ site-b-lb -- b-app1/b-app2
```

Use `/24`s under `10.115.0.0/16` for clients, DNS/control, site A, site B and
origins, with documentation addresses as published VIPs. Prebuild apps, PKI,
health endpoints and test clients. Withhold DNS policy, VIP/backends, checks,
persistence, TLS routes, cache and WAF/origin policy.

## Student task sequence

1. **Guided request-path survey:** trace DNS resolution, selected VIP, TLS/SNI,
   load balancer, cache and origin; inspect empty health/pool state.
2. **Hinted site-local service:** configure both LBs, L4/L7 health checks, forwarded
   client identity and graceful backend drain.
3. **Hinted TLS/SNI:** publish two names with correct certificates/routes and reject
   wrong SNI/hostname without a default-origin leak.
4. **Hinted GSLB:** select healthy sites by source/test policy, use bounded TTL, and
   withdraw a failed site based on application—not ICMP—health.
5. **Hinted persistence:** compare stateless round robin with cookie/source
   persistence, then drain a backend without breaking new sessions.
6. **Hinted cache/WAF:** cache a safe object, respect cache-control, protect origin,
   and apply a safe WAF test rule with observable logs.
7. **Open disaster case:** lose site A and explain which clients fail immediately,
   continue on established connections, or retain stale DNS; tune recovery without
   making TTL unrealistically tiny.
8. **Break-It:** the GSLB probe checks `/health` through an ACL-blocked source, so it
   withdraws a healthy site. Direct client requests would work, and site-local LB
   state is green. Diagnose probe source/path/status, repair the scoped ACL/health
   policy, and prove real unhealthy sites are still withdrawn.

## Make the invisible visible

- Timeline DNS query/cache expiry/site answer and subsequent TCP/TLS target.
- Display LB health reason, not only UP/DOWN.
- Correlate SNI/certificate/upstream Host and backend selection.
- Compare client, resolver, GSLB, cache, WAF and origin logs for one request ID.

## Automated checks

`check.sh` must assert at minimum:

1. Both site pools healthy in golden state.
2. GSLB returns intended healthy answer by test source/policy.
3. TLS hostname/certificate/SNI are correct.
4. Wrong SNI and direct origin access are denied.
5. Backend distribution and persistence match policy.
6. Drained backend receives no new sessions.
7. Failed app health withdraws site; ICMP-only health does not mask it.
8. Resolver cache obeys measured TTL.
9. Edge cache hit/miss/purge behavior is correct.
10. Safe WAF test acts/logs while normal request works.
11. Site loss preserves service after bounded DNS/cache behavior.
12. Health-probe Break-It fails on probe-path assertion despite healthy local pool.

## Planned files/docs

- Standard lab files, pinned service image(s), PKI, DNS health controller, cache/WAF
  rules, timeline test tool, `PROBE.md`, and `VALIDATION.md`.
- `docs/tracks/enterprise/global-application-delivery.md`, sequenced after
  `load-balancer-basics` and `anycast-dns`.

## Resource target

- Linux-first; ≤ 5 GiB steady, readiness ≤ 120 seconds.

## Definition of done

All master gates apply. Validate backend/site failures, persistence/drain, DNS cache
timelines, TLS/SNI, origin bypass, cache/WAF behavior, false health withdrawal and
clean redeploy. Every failover claim must include measured client-visible timing.
