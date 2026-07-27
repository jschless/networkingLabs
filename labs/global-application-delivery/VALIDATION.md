# Validation Record — `global-application-delivery`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-27, WP-15 worker |
| Host OS/kernel | Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab/Docker versions | Containerlab `0.74.1` (`1866b3a2b`); Docker client/server `29.5.3` |
| Image tags/digests | local `global-delivery:local`, validated image ID `sha256:cdc0297fbd074dfb46f48e53d65e54b4b5076b097fe57f96577ec9bf382235ab`; Alpine and CoreDNS bases pinned by digest in `Dockerfile` |
| Service versions | HAProxy `3.2.21-r0`; nginx `1.28.3-r7`; CoreDNS `1.12.2`; dnsmasq `2.91-r1`; OpenSSL `3.5.7-r0`; curl `8.14.1-r3` |
| Repository revision | validation working tree on `codex/lab-global-application-delivery`, based directly on `origin/main` `c12bab6` |

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Image build | `docker build -t global-delivery:local labs/global-application-delivery/` — success | cached base/package layer; PKI layer 0.5 s | image ID above |
| First clean deploy | `./scripts/lab.sh deploy global-application-delivery` — 16/16 containers running | 5.59 s | runner max RSS 42,080 KiB |
| Blank-state readiness | DNS answer empty; HAProxy/GSLB controller/edge cache PID files absent; origin nginx ready | immediate after deploy | included below |
| Completed student end state | wrote HAProxy and nginx runtime files from the documented task parameters/stanzas without copying repository source configs; `observer` timeline returned verified shop certificate, site A, `a-app1`, and request ID `trace-001` | ready within 5 s after apply | steady aggregate initially about 84 MiB |
| Healthy/check | `./scripts/lab.sh check global-application-delivery` — **28 passed, 0 failed** | about 20 s including 6 s stale-cache expiry and 8 s resolver observation | monitored peak 84.76 MiB; post-check steady 84.01 MiB |
| Break-It failure | `break-it.sh`, 5 s convergence, then check — **7 passed, 1 intended failure** | 5 s to observe | local pools stayed `UP/L7OK` |
| Minimal repair/check | `repair-break-it.sh`, then full check — **28 passed, 0 failed** | 5 s restore plus check | within same peak envelope |
| First destroy/cleanup | `./scripts/lab.sh destroy global-application-delivery` — no containers/network/generated lab directory | 4.14 s | runner max RSS 42,036 KiB |
| Clean redeploy | deploy repeated; all feature policy again withheld | 5.47 s | runner max RSS 41,984 KiB |
| Repeat completed path | configure, full **28/0** check with active aggregate monitor | same bounded test intervals | peak 84.76 MiB; steady 84.01 MiB |
| Final destroy/cleanup | scoped destroy; current-lab containers, networks, probe resources and generated directories all zero | 3.34 s | runner max RSS 42,296 KiB |
| README-only student candidate walk | clean deploy; generated both HAProxy candidates and the edge nginx candidate from README parameters/stanzas (no `/opt/gad/*.cfg` or repository config copy); full check **28/0** | bounded intervals repeated | within validated envelope |
| Post-student-walk cleanup | scoped destroy; containers, networks and generated directories again zero | under 3 s | not separately sampled |

The deployed topology is far below the 5 GiB steady target and the 120-second
readiness target. Aggregate container memory includes four Linux bridge
containers as well as all service nodes.

## Positive and negative evidence

Positive assertions proven live:

- both site pools reported both origins `UP` with `L7OK`, HTTP 200, and an
  application-layer health reason;
- authoritative near-A/near-B policy selected `192.0.2.10`/`198.51.100.10`;
- the `shop.gad.test` certificate chain and SAN verified against the local CA;
- cookie persistence retained one backend while stateless requests reached both;
- runtime drain removed `a-app1` from new sessions and was reset to ready;
- normal traffic carried client/request identity and the request ID appeared in
  HAProxy and origin logs;
- edge behavior produced `MISS`, `HIT`, post-purge `MISS`, and `STALE` after the
  five-second freshness window with origins unavailable;
- stopping both site-A origin nginx processes withdrew the site while ICMP to
  the same nodes remained healthy, then restored it after real HTTP recovery;
- losing site A left the primed resolver answer stale briefly, changed the
  authoritative view first, and converged the resolver to site B in 8 seconds;
- a new HTTPS request then succeeded at site B.

Negative assertions proven live:

- unknown SNI failed the TLS handshake;
- a client could not route directly to a site origin;
- the exact `?waf-test=1` signature returned 403 while a normal request returned
  200;
- a drained origin received no new session;
- the planned Break-It returned 403 only to the GSLB source/path, withdrew site
  A despite green local pools, and made `check.sh` return non-zero.

Break-It diagnosis used only visible state:

```text
site-a sticky_pool/a-app1 and a-app2: UP, L7OK
near-a authoritative answer: 198.51.100.10 (unexpected fallback)
health log: site_a=DOWN code=403
```

The minimal repair removed the source-specific health deny; it did not weaken
the separate public WAF test rule. A subsequent real origin failure still
withdrew site A.

## Repository gates

Run after the final scoped destroy:

```text
$ python3 scripts/lint-labs.py
OK — 136 labs checked, 46 distinct images, all consistent

$ ./scripts/check-docs-admonitions.sh
OK: no malformed admonitions in docs/

$ mkdocs build --strict
Documentation built in 16.56 seconds

$ shellcheck -S warning scripts/*.sh labs/*/check.sh
(no output; exit 0)

$ shellcheck -S warning labs/global-application-delivery/*.sh \
    labs/global-application-delivery/configs/**/*.sh \
    labs/global-application-delivery/probe/probe.sh
(no output; exit 0)
```

The supplemental `python3 scripts/validate-enterprise-coverage.py` still returns
one pre-existing unrelated finding: topic #14 points to the absent
`labs/fixtures/wireless-core-operations`. This branch does not alter that
wireless fixture ownership. The new application-delivery entry itself validates
under `lint-labs.py`.

## Limitations, refresh, and cleanup

- **Unsupported/evidence-only:** provider anycast, geo/latency routing, commercial
  health APIs, DDoS scrubbing, commercial WAF signatures and Internet-scale
  distributed cache coherence are conceptual mappings. The lab provides live
  local DNS/load-balancer/cache mechanisms only.
- **Connection scope:** the lab observes HAProxy drain state and new-session
  behavior. It does not claim that an established TCP connection can migrate
  between sites; it cannot.
- **TLS:** the CA and leaf keys are disposable lab material generated during the
  image build. They are not production identities and no static secret is
  committed.
- **Vulnerability refresh:** Alpine `3.22.1` and CoreDNS `1.12.2` are digest
  pinned; apk packages are exact-version pinned. Refresh requires the same probe,
  full lifecycle, and policy-negative checks.
- **Residual runtime artifacts:** final counts were zero for
  `clab-global-application-delivery-*` containers, lab/probe networks, probe
  containers, and generated `clab-*` directories. The reusable local image
  remains by design.
- **Follow-ups not represented as complete:** no optional cEOS/anycast topology,
  provider sandbox, real geography, real DDoS protection, or commercial WAF/CDN
  integration is claimed.
