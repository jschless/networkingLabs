#!/usr/bin/env bash
set -euo pipefail
prefix=clab-troubleshooting-range-hybrid-access
dir="$(cd "$(dirname "$0")" && pwd)"
credential=/run/range-client-certificate.env

"$dir/clear.sh"
docker exec "$prefix-managed-client" sh -c "umask 077; {
    echo 'certificate_id=managed-user-device-01'
    echo 'subject=CN=managed-user'
    echo 'issuer=Hybrid-Access-Device-CA'
    echo 'not_after_epoch=1735689600'
    echo 'trust=untrusted'
    echo 'identity_assertion=managed-expired'
} > '$credential'"

assertion="$(
    docker exec "$prefix-managed-client" \
        awk -F= '$1 == "identity_assertion" { print $2 }' "$credential"
)"
probe=(docker exec "$prefix-managed-client" python3 /opt/range/http_probe.py)

"${probe[@]}" 10.70.30.30 9443 identity-denied \
    "X-Client-Cert=$assertion" >/dev/null
"${probe[@]}" 10.70.30.30 9443 protected-app-ok \
    X-Client-Cert=managed-valid >/dev/null
"${probe[@]}" 10.70.41.40 8080 cloud-app-a-ok >/dev/null
"${probe[@]}" 10.70.42.40 8080 cloud-app-b-ok >/dev/null
docker exec "$prefix-managed-client" \
    dig +short @10.70.53.53 protected.hybrid.test A | grep -qx 10.70.30.30
docker exec "$prefix-managed-client" \
    ip route get 10.70.30.30 | grep -q 'via 10.70.10.1'

echo "Ticket symptom is active: this managed credential is denied while the protected service, routing, DNS, and general applications remain healthy."
