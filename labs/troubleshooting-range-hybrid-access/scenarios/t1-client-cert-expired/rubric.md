# Proctor rubric — TR-HA-102 (confidential)

**Root cause:** The runtime managed-user credential record on `managed-client`
contains an expired device client certificate (`not_after_epoch=1735689600`,
2025-01-01 00:00:00 UTC). Its trust state is `untrusted`, so the PEP correctly
rejects its `managed-expired` identity assertion. DNS, routing, the protected
service, the PEP process, general applications, and the origin policy are
healthy.
**Pass threshold:** 70/100 and the scenario `verify.sh` must pass.
**Tier time band:** 20 minutes, provisional until a human blind pilot is recorded.

## Diagnostic decision path

1. Reproduce the denial from `managed-client`, then compare general applications
   and a known-valid protected-path assertion to bound the outage to this user.
2. Inspect `/run/range-client-certificate.env`; compare `not_after_epoch` with
   the current UTC epoch and note the `untrusted` state.
3. Confirm that DNS and routing reach the PEP; do not change the service,
   forwarding policy, or direct-origin controls.
4. Renew only the runtime credential record with a future validity boundary,
   trusted state, and `managed-valid` assertion.
5. Run `./range.sh verify` and record the restored approved path plus rejected
   expired, untrusted, invalid, absent, and direct-origin paths.

## Weighted evidence milestones

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Reproduces this credential's denial and bounds it against healthy general applications and the known-valid protected path | 20 | −10 if only the denial is tested; −20 if scope is assumed |
| Reads the credential record and proves its 2025 validity boundary is past the current UTC epoch and its trust state is `untrusted` | 30 | −15 if only expiry or trust is noted; −30 for a cause asserted without endpoint evidence |
| Confirms the protected destination resolves to `10.70.30.30` and the route uses the managed workstation gateway | 10 | −5 per skipped check; −10 for an unsupported routing or DNS change |
| Renews only the runtime credential record with the same identity and issuer, future expiry, trusted state, and `managed-valid` assertion | 25 | −25 for weakening PEP validation, accepting any assertion, exposing the origin, or changing unrelated network/service state |
| Runs the mandatory verifier and documents approved-path success plus expired/untrusted and direct-origin denial | 15 | −15 if the verifier is not run; −8 if negative validation evidence is omitted |

Useful evidence commands:

```bash
./range.sh shell managed-client
cat /run/range-client-certificate.env
date -u +%s
python3 /opt/range/http_probe.py 10.70.30.30 9443 identity-denied X-Client-Cert=managed-expired
python3 /opt/range/http_probe.py 10.70.30.30 9443 protected-app-ok X-Client-Cert=managed-valid
python3 /opt/range/http_probe.py 10.70.41.40 8080 cloud-app-a-ok
dig +short @10.70.53.53 protected.hybrid.test A
ip route get 10.70.30.30
```

Minimal repair on `managed-client`:

```bash
umask 077
{
    echo 'certificate_id=managed-user-device-01'
    echo 'subject=CN=managed-user'
    echo 'issuer=Hybrid-Access-Device-CA'
    echo 'not_after_epoch=1893456000'
    echo 'trust=trusted'
    echo 'identity_assertion=managed-valid'
} > /run/range-client-certificate.env
```

This models device-certificate renewal and client-certificate/TLS validation in
the range's provider-neutral identity PEP; it does not claim a production PKI
or modify source-mounted configuration.

Red flags: disabling client-certificate/TLS assertion validation, accepting
expired, untrusted, invalid, or absent credentials, changing the PEP process,
exposing the protected origin, adding a host-file override, broad forwarding
changes, service shutdown, or any container restart caps the score at 69.
Passing requires `./range.sh verify`; portal recovery alone is insufficient.
