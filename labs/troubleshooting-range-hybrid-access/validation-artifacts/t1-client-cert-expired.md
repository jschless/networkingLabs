# Sanitized dry-run transcript — TR-HA-102

**Date:** 2026-07-29 UTC
**Topology:** frozen `1.0.0`
**Outcome:** pass

## Clean deployment and start

A scoped deploy from no existing hybrid-access resources completed with the
`ops-lab:local` image. Both the deploy health gate and the explicit pre-start
status returned:

```text
Results: 23 passed, 0 failed
```

The final-code dry run then established the ticket:

```text
$ ./range.sh start t1-client-cert-expired
Results: 23 passed, 0 failed
Ticket symptom is active: this managed credential is denied while the protected
service, routing, DNS, and general applications remain healthy.
FINAL_START_ELAPSED=2.66
```

## Rubric evidence

The runtime endpoint record exposed the direct T1 evidence:

```text
$ cat /run/range-client-certificate.env
certificate_id=managed-user-device-01
subject=CN=managed-user
issuer=Hybrid-Access-Device-CA
not_after_epoch=1735689600
trust=untrusted
identity_assertion=managed-expired

$ date -u +%s
1785321286
```

The `2025-01-01 00:00:00 UTC` validity boundary was in the past. The affected
assertion was denied while a known-valid assertion and general applications
were healthy:

```text
$ python3 /opt/range/http_probe.py 10.70.30.30 9443 identity-denied X-Client-Cert=managed-expired
PASS 10.70.30.30:9443 contains identity-denied
$ python3 /opt/range/http_probe.py 10.70.30.30 9443 protected-app-ok X-Client-Cert=managed-valid
PASS 10.70.30.30:9443 contains protected-app-ok
$ python3 /opt/range/http_probe.py 10.70.41.40 8080 cloud-app-a-ok
PASS 10.70.41.40:8080 contains cloud-app-a-ok
$ python3 /opt/range/http_probe.py 10.70.42.40 8080 cloud-app-b-ok
PASS 10.70.42.40:8080 contains cloud-app-b-ok
```

DNS and the route to the protected PEP were correct:

```text
$ dig +short @10.70.53.53 protected.hybrid.test A
10.70.30.30
$ ip route get 10.70.30.30
10.70.30.30 via 10.70.10.1 dev eth1 src 10.70.10.10
```

## Minimal repair and verification

Only `/run/range-client-certificate.env` was renewed. The identity, issuer, and
certificate ID were retained; the validity boundary became `1893456000`
(`2030-01-01 00:00:00 UTC`), trust became `trusted`, and the assertion became
`managed-valid`. No service or container was restarted.

```text
$ ./range.sh verify
PASS: the renewed trusted credential reaches the protected application through
the PEP; client-certificate validation still denies expired, untrusted,
invalid, and absent credentials; direct origin access and default-deny policy
remain intact.
FINAL_VERIFY_ELAPSED=1.62
```

For the negative workaround test, the running PEP process was temporarily
replaced with a writable `/run` copy that accepted every assertion. The
verifier failed on the expired-credential denial and reported the unexpected
`protected-app-ok` response:

```text
PASS: verifier rejected disabled client-certificate/TLS assertion validation.
```

The read-only golden PEP was restored without a container restart, after which
the verifier passed again.

## Reset, resources, and cleanup

`clear.sh` completed successfully twice before reset, demonstrating
idempotence. Reset cleared the active attempt, restored golden runtime state,
and the health gate plus explicit post-reset status each returned:

```text
Results: 23 passed, 0 failed
FINAL_RESET_ELAPSED=10.84
```

The post-reset scoped resource snapshot contained nine containers using
approximately 33.6 MiB total memory. The largest individual consumers were
`origin-a` (9.875 MiB), `origin-b` (9.867 MiB), and `pep` (9.75 MiB); reported
CPU was at most 0.03%.

Finally, `./range.sh destroy` removed only this topology. Explicit checks found
no `clab-troubleshooting-range-hybrid-access-*` containers, no
`clab-troubleshooting-range-hybrid-access-mgmt` network, and no generated lab
directory.
