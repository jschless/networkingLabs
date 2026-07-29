#!/usr/bin/env bash
set -euo pipefail
prefix=clab-troubleshooting-range-hybrid-access
credential=/run/range-client-certificate.env
probe=(docker exec "$prefix-managed-client" python3 /opt/range/http_probe.py)

record="$(docker exec "$prefix-managed-client" cat "$credential")"
field() {
    local key=$1
    printf '%s\n' "$record" |
        awk -v key="$key" 'index($0, key "=") == 1 { sub(/^[^=]*=/, ""); print }'
}

[[ "$(field certificate_id)" == managed-user-device-01 ]]
[[ "$(field subject)" == CN=managed-user ]]
[[ "$(field issuer)" == Hybrid-Access-Device-CA ]]
[[ "$(field trust)" == trusted ]]
[[ "$(field identity_assertion)" == managed-valid ]]
not_after_epoch="$(field not_after_epoch)"
[[ "$not_after_epoch" =~ ^[0-9]+$ ]]
(( not_after_epoch > $(date +%s) + 86400 ))

"${probe[@]}" 10.70.30.30 9443 protected-app-ok \
    "X-Client-Cert=$(field identity_assertion)" >/dev/null
"${probe[@]}" 10.70.30.30 9443 identity-denied \
    X-Client-Cert=managed-expired >/dev/null
"${probe[@]}" 10.70.30.30 9443 identity-denied \
    X-Client-Cert=managed-untrusted >/dev/null
"${probe[@]}" 10.70.30.30 9443 identity-denied \
    X-Client-Cert=invalid >/dev/null
"${probe[@]}" 10.70.30.30 9443 identity-denied >/dev/null
"${probe[@]}" --expect-denied 10.70.41.40 8443 >/dev/null
"${probe[@]}" --expect-denied 2001:db8:70:41::40 8443 >/dev/null

docker exec "$prefix-pep" sh -c \
    "tr '\\000' ' ' < /proc/\$(cat /run/range-pep.pid)/cmdline | grep -q '/opt/range/pep_proxy.py'"
docker exec "$prefix-cloud-edge" sh -c \
    "iptables -S FORWARD | grep -qx -- '-P FORWARD DROP'"
docker exec "$prefix-cloud-edge" sh -c \
    "ip6tables -S FORWARD | grep -qx -- '-P FORWARD DROP'"
docker exec "$prefix-managed-client" sh -c \
    "! grep -q 'hybrid\\.test' /etc/hosts"

echo "PASS: the renewed trusted credential reaches the protected application through the PEP; client-certificate validation still denies expired, untrusted, invalid, and absent credentials; direct origin access and default-deny policy remain intact."
