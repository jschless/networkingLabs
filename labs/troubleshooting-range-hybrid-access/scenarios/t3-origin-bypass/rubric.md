# Proctor rubric — TR-HA-301 (confidential)

**Root cause:** Two runtime allow rules on `cloud-edge` precede the protected
origin rejects, exposing `origin-a` TCP/8443 directly to the managed-client
prefix over IPv4 and IPv6. The PEP and its identity decision are healthy.
**Pass threshold:** 80/100 and the scenario `verify.sh` must pass.
**Tier time band:** 60 minutes, provisional until a human blind pilot is recorded.

## Diagnostic decision path

1. Compare a valid and invalid identity through `pep` with direct `origin-a`
   reachability; do not assume a failed PEP.
2. Separate name resolution, request path, origin service, and return path with
   endpoint probes and the `cloud-edge` ordered forwarding rules.
3. Identify the higher-priority direct-origin permits in both address families.
4. Remove only those permits, retaining the PEP-to-origin allow and default deny.
5. Run `./range.sh verify` and document approved-path success plus both direct denials.

## Weighted evidence milestones

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Demonstrates valid identity success, invalid identity denial, and direct origin exposure | 20 | −10 for testing only one path; −20 if the security report is not reproduced |
| Separates DNS, PEP decision, origin response, and return routing with evidence | 20 | −5 per skipped layer; −15 for blaming the PEP despite contrary evidence |
| Finds both ordered `range-t3-origin-bypass` permits ahead of the denies | 25 | −12 if only IPv4 is found; −25 for a cause asserted without ruleset evidence |
| Removes only the two bypass permits and preserves PEP-to-origin policy | 20 | −20 for host-only blocking, default deny/allow changes, broad ACLs, or service shutdown |
| Runs the mandatory verifier and records the positive and negative architecture assertions | 15 | −15 if verifier is absent; −8 if only direct denial is documented |

Useful evidence commands:

```bash
./range.sh shell managed-client
python3 /opt/range/http_probe.py 10.70.30.30 9443 protected-app-ok X-Client-Cert=managed-valid
python3 /opt/range/http_probe.py 10.70.30.30 9443 identity-denied X-Client-Cert=invalid
python3 /opt/range/http_probe.py 10.70.41.40 8443 protected-origin-ok

./range.sh shell cloud-edge
ip route get 10.70.10.10
iptables -S FORWARD
ip6tables -S FORWARD
```

Minimal repair:

```bash
iptables -D FORWARD -s 10.70.10.0/24 -d 10.70.41.40 -p tcp --dport 8443 -m comment --comment range-t3-origin-bypass -j ACCEPT
ip6tables -D FORWARD -s 2001:db8:70:10::/64 -d 2001:db8:70:41::40 -p tcp --dport 8443 -m comment --comment range-t3-origin-bypass -j ACCEPT
```

Red flags: disabling the PEP, shutting down the application, blocking only on
the origin host, adding a host-file entry, removing DNS, changing the default
route, broad policy changes, or restarting a container caps the score at 79.
Passing requires `./range.sh verify`; a single denied direct request is not
proof that the required PEP architecture still works.
