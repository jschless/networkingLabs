# Feature Probe Record — `global-application-delivery`

## Scope and decision

- **Feature and learning objective:** prove that real application probes can drive
  authoritative DNS withdrawal, a caching resolver retains an answer only for a
  bounded TTL, locally issued certificates enforce SNI, a safe request rule denies
  only its test signature, and HAProxy exposes runtime drain state.
- **Decision:** **go** with the Linux-first plan; no cEOS routers or fallback.
- **Reason and fidelity statement:** the pinned HAProxy, nginx, CoreDNS, dnsmasq,
  and OpenSSL components performed every load-bearing mechanism. The lab is a
  local GSLB/cache analogue, not a claim of global anycast, geo/latency steering,
  commercial WAF inspection, DDoS scrubbing, or an internet-scale CDN.
- **Owner and date:** WP-15 worker, 2026-07-27.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab version | `0.74.1` (`1866b3a2b`) |
| Docker version | client/server `29.5.3` |
| Base image | `alpine:3.22.1@sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1` |
| CoreDNS image | `coredns/coredns:1.12.2@sha256:af8c8d35a5d184b386c4a6d1a012c8b218d40d1376474c7d071bb6c07201f47d` |
| Service versions | HAProxy `3.2.21-r0`; nginx `1.28.3-r7`; dnsmasq `2.91-r1`; OpenSSL `3.5.7-r0`; curl `8.14.1-r3` |
| Probe-built image ID | `sha256:cdc0297fbd074dfb46f48e53d65e54b4b5076b097fe57f96577ec9bf382235ab` after PKI layer was added; behavioral probe image before that layer was `sha256:def0e2169440665742c07c397d00940a63f9f55f35185dc1cbe01decedb20225` |
| Host memory/disk before probe | 15 GiB RAM total, 1.4 GiB used, 13 GiB available; 143 GiB disk available |

## Smallest load-bearing test

The disposable harness used five containers on `10.115.250.0/24`: two combined
nginx/HAProxy sites, CoreDNS plus the real HTTP health controller, dnsmasq, and a
client. It generated a seven-day probe CA locally and cleaned all probe resources.

```text
$ /usr/bin/time -v labs/global-application-delivery/probe/probe.sh
initial_answers=192.0.2.10,198.51.100.10,
tls_sni=PASS
wrong_sni=PASS
safe_waf_rule=PASS
authoritative_withdraw_seconds=5 answers=198.51.100.10,
resolver_immediate_cached_answers=192.0.2.10,198.51.100.10,
resolver_cache_expiry_seconds=9 answers=198.51.100.10,
runtime_drain_observable=PASS
gad-probe-client 408KiB / 15.37GiB
gad-probe-resolver 396KiB / 15.37GiB
gad-probe-gslb 11.34MiB / 15.37GiB
gad-probe-site-a 46.32MiB / 15.37GiB
gad-probe-site-b 53.64MiB / 15.37GiB
elapsed_seconds=16
```

Peak observed container memory was about **112 MiB combined**. The successful
cached-answer interval was 9 seconds from failure, consistent with the configured
8-second TTL plus one-second sampling.

Three earlier harness runs were retained in the work log rather than treated as
platform failures:

1. The first used a four-second TTL but performed TLS/WAF checks after priming, so
   the cache had legitimately expired before the failure.
2. The corrected cache run reached the drain assertion, but attempted two HAProxy
   runtime commands on one socket connection; HAProxy processed only the first.
3. The next run made the same query after separating the socket connection but
   used an overly strict output grep.

Restarting/priming dnsmasq immediately before failure and querying HAProxy state
on a separate runtime-socket connection made the experiment bounded and repeatable.

## Cleanup and repeatability

- **Destroy/cleanup command:** the probe's `trap cleanup EXIT` runs
  `docker rm -f gad-probe-{client,resolver,gslb,site-a,site-b}` and
  `docker network rm gad-feature-probe`, then removes its `mktemp` directory.
- **Orphan check:** `docker ps -a --filter name=gad-probe` and
  `docker network ls --filter name=gad-feature-probe` returned no resources.
- **Repeat result:** the final corrected run passed from a clean state; the full
  topology subsequently reproduced the same TLS, withdrawal, cache, and drain
  mechanisms.

## Unsupported behavior and fallback

No fallback was taken. The optional cEOS/anycast path was unnecessary and would
have shifted the lab away from application delivery. Provider APIs, Internet BGP
anycast, real geography/latency, commercial WAF signatures, DDoS scrubbing, and
distributed cache coherency remain conceptual mappings only.
