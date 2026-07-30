# Sanitized dry-run transcript — TR-HA-104

**Date:** 2026-07-29 UTC
**Topology:** frozen `1.0.0`
**Base:** `c45cdc5e8119` (`origin/main` at branch creation)
**Outcome:** pass

## Environment and clean start

The final-code acceptance used ContainerLab `0.74.1` commit `1866b3a2b`,
Docker Engine `29.5.3`, and the existing `ops-lab:local` image
`sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`
(68,762,000 bytes). No hybrid-access containers, management network, generated
lab directory, or active attempt existed before deploy.

The clean deploy completed in `11.70` seconds. Its health gate and the explicit
pre-start status each returned:

```text
Results: 23 passed, 0 failed
FINAL_STATUS_ELAPSED=2.26
```

The final-code injector then proved the ticket in `3.14` seconds:

```text
Ticket symptom is active: health-driven service results omit site B even though
its regional application and health endpoint remain healthy.
```

## Rubric evidence

The affected shared name returned only site A in both address families, while
site B's regional application and health endpoint remained usable:

```text
$ dig +short @10.70.53.53 global.hybrid.test A
10.70.41.40
$ dig +short @2001:db8:70:53::53 global.hybrid.test AAAA
2001:db8:70:41::40
$ python3 /opt/range/http_probe.py 10.70.42.40 8080 cloud-app-b-ok
PASS 10.70.42.40:8080 contains cloud-app-b-ok
$ python3 /opt/range/http_probe.py 10.70.42.40 8081 cloud-health-b-ok
PASS 10.70.42.40:8081 contains cloud-health-b-ok
```

The runtime controller record and an immediate independent probe check showed
the same direct T1 evidence:

```text
generation_mode=health-probe
probe_source=10.70.53.53
probe_port=8081
site_a_endpoint=10.70.41.40:8081
site_a=healthy
site_b_endpoint=10.70.42.40:8081
site_b=down
```

The source-specific route was correct:

```text
$ ip route get 10.70.42.40 from 10.70.53.53
10.70.42.40 from 10.70.53.53 via 10.70.53.1 dev eth1
```

Ordered runtime policy exposed the cause. The site-B reject preceded its exact
source-limited permit, while the corresponding site-A permit was also present:

```text
-A FORWARD -s 10.70.53.53/32 -d 10.70.42.40/32 -p tcp --dport 8081 -m comment --comment range-t1-gslb-probe-deny -j REJECT
-A FORWARD -s 10.70.53.53/32 -d 10.70.42.40/32 -p tcp --dport 8081 -m comment --comment range-t1-gslb-probe-allow -j ACCEPT
-A FORWARD -s 10.70.53.53/32 -d 10.70.41.40/32 -p tcp --dport 8081 -m comment --comment range-t1-gslb-probe-allow -j ACCEPT
```

## Minimal repair, verifier, and adversarial check

Only the marked site-B reject was deleted. The controller's next health cycle
reported both sites healthy and republished both A and AAAA site answers. No
service or container was restarted.

The final-code verifier passed in `0.91` seconds:

```text
PASS: fresh source-bound health probes mark both sites healthy, health-driven
A/AAAA results contain both sites, narrow probe policy and default deny remain
intact, and forced static answers or host overrides do not satisfy this
verifier.
```

The adversarial check reintroduced the probe deny, paused health publishing,
and forced both sites into the writable runtime hosts source. Queries then
appeared recovered:

```text
FORCED_STATIC_A_ANSWERS:
10.70.41.40
10.70.42.40
FORCED_STATIC_AAAA_ANSWERS:
2001:db8:70:41::40
2001:db8:70:42::40
```

`./range.sh verify` exited `1` because its fresh source-bound site-B probe
still failed. Removing the deny and resuming health publishing returned the
verifier to green. This proves a forced static answer cannot mask the fault.

## Idempotence, reset, resources, and cleanup

Two direct `clear.sh` calls completed in `0.52` and `0.13` seconds. They left
no controller process/file, runtime DNS config/hosts/state, or marked policy
rule. The final acceptance reset completed in `10.41` seconds, and both its
health gate and the explicit post-reset status returned:

```text
Results: 23 passed, 0 failed
FINAL_POST_STATUS_ELAPSED=2.24
```

All nine containers retained restart count `0`. The active-scenario snapshot
used approximately `40.1 MiB` total memory; the largest consumers were
`origin-a` (`9.895 MiB`), `origin-b` (`9.875 MiB`), `pep` (`9.742 MiB`), and
the runtime-controller `dns` node (`7.395 MiB`). Reported CPU was at most
`0.07%`.

Scoped destroy completed in `1.94` seconds. Explicit audits found zero
hybrid-access containers, management networks, named links, generated lab
directories, SSH includes, active attempt markers, or GSLB attempt
directories. Only the two attempt directories created by this validation were
removed; six pre-existing attempt directories for other tickets were
preserved.

## Repository gates and diff safety

| Gate | Result |
|---|---|
| `python3 scripts/validate_ticket.py .../t1-gslb-probe-source-acl` | Passed |
| Scenario Bash syntax and controller Python syntax parse | Passed |
| Scenario plus range-controller/health/check ShellCheck | Passed |
| `python3 scripts/lint-labs.py` | Passed: 143 labs, 52 images |
| `./scripts/check-docs-admonitions.sh` | Passed |
| `mkdocs build --strict` | Passed in 21.18 seconds |
| `git diff --check` | Passed |

The scoped diff adds one scenario directory, this validation record, and the
required catalog status/count update. It does not change frozen topology
`1.0.0`, shared controller/reset/health behavior, source mounts, addressing,
healthy policy, nodes, links, images, or foundation design.
