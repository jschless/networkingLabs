# Sanitized dry-run transcript — TR-HA-201

**Date:** 2026-07-30 UTC
**Topology:** frozen `1.0.0`
**Base:** `ff8bf1d34514` (`origin/main` at branch creation)
**Outcome:** pass

## Environment and clean start

The acceptance used ContainerLab `0.74.1` commit `1866b3a2b`, Docker Engine
`29.5.3`, and the existing `ops-lab:local` image
`sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`
(68,762,000 bytes). Before deploy there were no hybrid-access containers,
management network, generated lab directory, or active attempt.

Clean deploy completed in `12.91` seconds. Its health gate and the explicit
pre-start status each returned:

```text
Results: 23 passed, 0 failed
FINAL_STATUS_ELAPSED=2.33
```

After a final-code green status, the injector completed in `10.85` seconds and
proved the ticket symptom:

```text
Ticket symptom is active: both preferred hybrid routes remain selected and
hosted services are healthy, but client requests receive no replies.
```

## Rubric evidence

Both managed-client application attempts timed out while the same services
answered from the hosted routing boundary:

```text
$ python3 /opt/range/http_probe.py 10.70.41.40 8080 cloud-app-a-ok
TimeoutError: timed out
EXPECTED_IPV4_FAILURE_EXIT=1

$ python3 /opt/range/http_probe.py 2001:db8:70:41::40 8080 cloud-app-a-ok
TimeoutError: timed out
EXPECTED_IPV6_FAILURE_EXIT=1

$ wget -qO- http://10.70.41.40:8080/
cloud-app-a-ok
$ wget -qO- 'http://[2001:db8:70:41::40]:8080/'
cloud-app-a-ok
```

The injector also required both affected name-service paths to time out:

```text
communications error to 10.70.53.53#53: timed out
FINAL_EXPECTED_IPV4_DNS_EXIT=9
communications error to 2001:db8:70:53::53#53: timed out
FINAL_EXPECTED_IPV6_DNS_EXIT=9
```

Campus forwarding still selected preferred WAN A in both address families:

```text
$ ip route get 10.70.41.40
10.70.41.40 via 10.70.12.2 dev eth2 src 10.70.12.1

$ ip -6 route get 2001:db8:70:41::40
2001:db8:70:41::40 from :: via 2001:db8:70:12::2 dev eth2
src 2001:db8:70:12::1 metric 10 pref medium
```

A client-side capture observed an outbound TCP SYN and no reply packet during
a second application attempt:

```text
IP 10.70.10.10.55696 > 10.70.41.40.8080: Flags [S]
1 packet captured
OUTBOUND_CAPTURE_EXIT=0

0 packets captured
0 packets received by filter
```

The hosted return lookups failed, and the full route tables exposed the wrong
lower-metric association without hiding the valid prefix routes:

```text
$ ip route get 10.70.10.10
RTNETLINK answers: Invalid argument
$ ip -6 route get 2001:db8:70:10::10
RTNETLINK answers: Invalid argument

$ ip route show exact 10.70.10.0/24
blackhole 10.70.10.0/24 metric 5
10.70.10.0/24 via 10.70.24.1 dev eth1 metric 10
10.70.10.0/24 via 10.70.25.1 dev eth2 metric 100

$ ip -6 route show exact 2001:db8:70:10::/64
blackhole 2001:db8:70:10::/64 dev lo metric 5 pref medium
2001:db8:70:10::/64 via 2001:db8:70:24::1 dev eth1 metric 10 pref medium
2001:db8:70:10::/64 via 2001:db8:70:25::1 dev eth2 metric 100 pref medium
```

## Minimal repair and verifier

Only the two lower-metric blackhole returns were deleted:

```text
ip route del blackhole 10.70.10.0/24 metric 5
ip -6 route del blackhole 2001:db8:70:10::/64 metric 5
```

The final-code verifier passed in `1.92` seconds. It proved both preferred and
standby prefix routes, dual-stack application and DNS service, the managed and
unmanaged identity decisions, direct-origin denial, default-deny forwarding,
and absence of `/32` or `/128` client workarounds.

```text
PASS: both preferred and standby transit return routes are intact, IPv4/IPv6
services work end to end, identity and origin policy remain enforced, and no
client host-route workaround exists.
```

## Workaround rejection

The adversarial check reintroduced both blackholes, then added a more-specific
IPv4 `/32` and IPv6 `/128` route for the affected workstation through WAN A.
Both reported application probes appeared restored:

```text
PASS 10.70.41.40:8080 contains cloud-app-a-ok
PASS 2001:db8:70:41::40:8080 contains cloud-app-a-ok
```

`./range.sh verify` exited `1` because the prefix return tables were still
wrong and the client host routes existed. Deleting the workaround routes and
running the scenario clearer twice returned the verifier to green in `1.95`
seconds.

## Reset, resources, and cleanup

The active-scenario resource snapshot used approximately `33.8 MiB` total
memory. The largest consumers were `origin-a` (`9.898 MiB`), `origin-b`
(`9.891 MiB`), and `pep` (`9.762 MiB`); reported CPU was at most `0.03%`.
All nine containers retained restart count `0`.

Final reset completed in `10.81` seconds. Its health gate and the explicit
post-reset status each returned:

```text
Results: 23 passed, 0 failed
FINAL_POST_STATUS_ELAPSED=2.26
```

The reset audit found only the golden metric-10 WAN A and metric-100 WAN B
prefix routes, no blackhole or host route, and no active attempt. Scoped
destroy completed in `2.07` seconds. Explicit checks found zero hybrid-access
containers, management networks, generated lab directories, SSH includes,
active attempt markers, or isolated validation-state directories. The one
validation attempt directory was removed; no pre-existing attempt history
was touched.

## Repository gates and diff safety

| Gate | Result |
|---|---|
| `python3 scripts/validate_ticket.py .../t2-transit-return-table` | Passed |
| Scenario Bash syntax and range-local ShellCheck | Passed |
| Repository script/check ShellCheck gate | Passed |
| `python3 scripts/lint-labs.py` | Passed: 143 labs, 52 images |
| `./scripts/check-docs-admonitions.sh` | Passed |
| `mkdocs build --strict` | Passed in 22.36 seconds |
| `git diff --check` | Passed |

The scoped diff adds one six-file scenario, this validation record, and the
required catalog status/count update. It does not change frozen topology
`1.0.0`, shared controller/reset/health behavior, source mounts, addressing,
healthy policy, nodes, links, images, or foundation design.
