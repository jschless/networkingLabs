# Sanitized dry-run transcript — TR-HA-101

**Date:** 2026-07-29 UTC
**Topology:** frozen `1.0.0` candidate
**Outcome:** pass

## Start and symptom proof

```text
$ ./range.sh start t1-workload-policy-port
Results: 23 passed, 0 failed
Ticket symptom is active: one application is denied while routing, health,
and the secondary site remain healthy.
T1_START elapsed=2.59
```

Rubric evidence from `managed-client`:

```text
$ python3 /opt/range/http_probe.py 10.70.41.40 8080 cloud-app-a-ok
ConnectionRefusedError: [Errno 111] Connection refused
$ python3 /opt/range/http_probe.py 10.70.41.40 8081 cloud-health-a-ok
PASS 10.70.41.40:8081 contains cloud-health-a-ok
$ python3 /opt/range/http_probe.py 10.70.42.40 8080 cloud-app-b-ok
PASS 10.70.42.40:8080 contains cloud-app-b-ok
$ dig +short @10.70.53.53 analytics.hybrid.test A
10.70.41.40
$ dig +short @2001:db8:70:53::53 analytics.hybrid.test AAAA
2001:db8:70:41::40
$ ip route get 10.70.41.40
10.70.41.40 via 10.70.10.1 dev eth1 src 10.70.10.10
```

Decisive ordered policy evidence:

```text
-A FORWARD -s 10.70.10.0/24 -d 10.70.41.40/32 -p tcp --dport 8080 \
  -m comment --comment range-t1-workload-port -j REJECT
-A FORWARD -s 2001:db8:70:10::/64 -d 2001:db8:70:41::40/128 \
  -p tcp --dport 8080 -m comment --comment range-t1-workload-port -j REJECT
```

## Minimal repair and verification

Only those two marked rejects were deleted.

```text
$ ./range.sh verify
PASS: both address families reach the intended application, adjacent services
remain healthy, direct protected-origin access stays denied, and no broad
bypass exists.
T1_VERIFY elapsed=0.43

$ ./range.sh reset
Results: 23 passed, 0 failed
T1_RESET elapsed=10.80
```

## Workaround rejection

A deliberately broad client-prefix-to-origin allow was inserted ahead of the
fault. It restored the reported application but also exposed the protected
origin; `verify.sh` failed and the harness reported:

```text
ERROR: 10.70.41.40:8443 was reachable
PASS: T1 verifier rejected broad subnet allow workaround
```

The broad rules were deleted, `range.sh reset` ran, and health returned 23/23.
