# Sanitized dry-run transcript — TR-HA-301

**Date:** 2026-07-29 UTC
**Topology:** frozen `1.0.0` candidate
**Outcome:** pass

## Start and symptom proof

```text
$ ./range.sh start t3-origin-bypass
Results: 23 passed, 0 failed
Ticket symptom is active: approved identity checks still work while both
direct origin paths are exposed.
T3_START elapsed=2.59
```

Rubric request-path evidence:

```text
$ python3 /opt/range/http_probe.py 10.70.30.30 9443 protected-app-ok X-Client-Cert=managed-valid
PASS 10.70.30.30:9443 contains protected-app-ok
$ python3 /opt/range/http_probe.py 10.70.30.30 9443 identity-denied X-Client-Cert=invalid
PASS 10.70.30.30:9443 contains identity-denied
$ python3 /opt/range/http_probe.py 10.70.41.40 8443 protected-origin-ok
PASS 10.70.41.40:8443 contains protected-origin-ok
$ python3 /opt/range/http_probe.py 2001:db8:70:41::40 8443 protected-origin-ok
PASS 2001:db8:70:41::40:8443 contains protected-origin-ok
```

Decisive ordered policy evidence:

```text
-A FORWARD -s 10.70.10.0/24 -d 10.70.41.40/32 -p tcp --dport 8443 \
  -m comment --comment range-t3-origin-bypass -j ACCEPT
-A FORWARD -s 10.70.30.30/32 -d 10.70.41.40/32 -p tcp --dport 8443 -j ACCEPT
-A FORWARD -s 10.70.10.0/24 -d 10.70.41.40/32 -p tcp --dport 8443 -j REJECT
```

The IPv6 rules had the same allow-before-reject ordering. Both return routes
selected WAN A, so the PEP decision, origin service, ordered cloud policy, and
return path were evaluated separately.

## Minimal repair and verification

Only the two marked direct-origin permits were deleted.

```text
$ ./range.sh verify
PASS: managed identity reaches the protected application only through the PEP,
unmanaged identity and direct origin paths are denied, and no host-file or
broad-policy workaround remains.
T3_VERIFY elapsed=1.43

$ ./range.sh reset
Results: 23 passed, 0 failed
T3_RESET elapsed=10.98
```

## Workaround rejection

Temporary origin-host input rejects masked both direct symptoms while the
architectural bypass rules remained. `verify.sh` rejected that endpoint-only
mask:

```text
PASS: T3 verifier rejected host-only origin mask
```

The host rules were deleted, `range.sh reset` ran, and health returned 23/23.
Both scenario clear scripts also succeeded twice in a clean state.
