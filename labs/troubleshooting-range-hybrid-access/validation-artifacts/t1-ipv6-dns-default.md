# Sanitized dry-run transcript — TR-HA-103

**Date:** 2026-07-29 UTC
**Topology:** frozen `1.0.0`
**Outcome:** pass

## Clean deployment and start

The acceptance run began with no hybrid-access containers, management network,
generated lab directory, or active attempt. It used ContainerLab `0.74.1`,
Docker Engine `29.5.3`, and the existing `ops-lab:local` image
`sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`.

The clean deploy and explicit pre-start status each returned:

```text
Results: 23 passed, 0 failed
ACCEPTANCE_DEPLOY_ELAPSED=11.74
ACCEPTANCE_STATUS_ELAPSED=2.27
```

The final-code injector then proved the symptom:

```text
$ ./range.sh start t1-ipv6-dns-default
Ticket symptom is active: IPv6 DNS and the default path are absent while the
advertised IPv6 settings remain visible and IPv4 application access stays
healthy.
ACCEPTANCE_START_ELAPSED=7.12
```

## Rubric evidence

The client retained global IPv6 addresses and the advertised IPv6 resolver,
but had no default route:

```text
$ ip -6 address show dev eth1
inet6 2001:db8:70:10:a8c1:abff:feef:874a/64 scope global dynamic mngtmpaddr
inet6 2001:db8:70:10::10/64 scope global nodad

$ ip -6 route show
2001:db8:70:10::/64 dev eth1 proto kernel metric 256 pref medium
fe80::/64 dev eth1 proto kernel metric 256 pref medium

$ cat /etc/resolv.conf
nameserver 2001:db8:70:53::53
```

System resolution and the IPv6 application request failed with
`network unreachable`, while the same application remained healthy over IPv4:

```text
$ dig +time=1 +tries=1 analytics.hybrid.test AAAA
;; UDP setup with 2001:db8:70:53::53#53 for analytics.hybrid.test failed:
;; network unreachable.
EXPECTED_DNS_FAILURE_EXIT=9

$ python3 /opt/range/http_probe.py 2001:db8:70:41::40 8080 cloud-app-a-ok
OSError: [Errno 101] Network unreachable
EXPECTED_IPV6_APP_FAILURE_EXIT=1

$ python3 /opt/range/http_probe.py 10.70.41.40 8080 cloud-app-a-ok
PASS 10.70.41.40:8080 contains cloud-app-a-ok
```

Direct endpoint evidence exposed the fault while a live capture proved the
upstream advertisement was healthy:

```text
$ sysctl net.ipv6.conf.eth1.accept_ra
net.ipv6.conf.eth1.accept_ra = 0

$ timeout 10 tcpdump -ni eth1 -c 1 -vv 'icmp6 and ip6[40] == 134'
ICMP6, router advertisement
router lifetime 60s
rdnss option (25): lifetime 60s, addr: 2001:db8:70:53::53
```

## Minimal repair and verification

Only interface RA acceptance was enabled:

```text
$ sysctl -w net.ipv6.conf.eth1.accept_ra=1
net.ipv6.conf.eth1.accept_ra = 1

$ ip -6 route show default
default via fe80::a8c1:abff:fe35:e300 dev eth1 proto ra metric 1024
```

The verifier then passed in `5.69` seconds. It proved the sole default was a
live `proto ra` route, used the IPv6 RDNSS service to obtain the expected AAAA
answer, reached the application over IPv6, and retained direct protected-origin
denial.

Adversarial checks temporarily replaced the resolver with IPv4-only
`10.70.53.53` and separately added a static IPv6 default. In both cases
`./range.sh verify` exited `1`. Restoring the advertised IPv6 resolver and
removing the static route returned the verifier to green.

## Idempotence, resources, reset, and cleanup

Both direct `clear.sh` calls succeeded. The audit found the Docker-generated
resolver restored in place, the golden static default restored, `accept_ra=1`,
no resolver backup/config/PID marker, and no RA or supervisor process,
including no zombie. All nine containers retained restart count `0`.

The active-scenario resource snapshot used approximately `39.366 MiB` total
memory. The largest consumers were `origin-a` (`9.867 MiB`), `origin-b`
(`9.867 MiB`), `pep` (`9.742 MiB`), and the runtime RA node
`campus-edge` (`6.316 MiB`). Reported CPU was at most `0.03%`.

The final reset and explicit post-reset status each returned:

```text
Results: 23 passed, 0 failed
ACCEPTANCE_RESET_ELAPSED=10.21
ACCEPTANCE_POST_RESET_STATUS_ELAPSED=2.23
```

Finally, scoped destroy completed in `1.95` seconds. Explicit checks found no
`clab-troubleshooting-range-hybrid-access-*` containers, no
`clab-troubleshooting-range-hybrid-access-mgmt` network, no generated lab
directory, and no active attempt. Closed attempt evidence remains only in the
range's designed external attempt history.

## Repository gates

| Gate | Result |
|---|---|
| `python3 scripts/validate_ticket.py .../t1-ipv6-dns-default` | Passed |
| Scenario and range-local `shellcheck -S warning` | Passed |
| `python3 scripts/lint-labs.py` | Passed: 143 labs, 52 images |
| `./scripts/check-docs-admonitions.sh` | Passed |
| `mkdocs build --strict` | Passed |
| Repository script/check ShellCheck gate | Passed |
| `git diff --check` | Passed |

The scoped diff adds one scenario, this validation record, and the required
catalog status/count update. It does not change the frozen topology, shared
foundation, source mounts, healthy policy, topology version, or image.
