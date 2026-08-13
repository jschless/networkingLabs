#!/usr/bin/env bash
# Apply and save the complete healthy learned state. Re-running is safe.
set -euo pipefail

prefix=clab-ipsec-basics
lab_dir=$(cd "$(dirname "$0")" && pwd)

for node in gw-a gw-b host-a host-b internet; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: ipsec-basics is not fully deployed" >&2
        exit 1
    }
done

docker exec "$prefix-gw-a" su - admin -c \
    '/bin/vbash /opt/ipsec-basics/apply-solution.sh' >/dev/null
docker exec "$prefix-gw-b" su - admin -c \
    '/bin/vbash /opt/ipsec-basics/apply-solution.sh' >/dev/null
docker exec "$prefix-gw-a" bash -lc \
    "su - admin -c \"/bin/vbash -ic 'reset vpn ipsec site-to-site peer GW-B'\"" \
    >/dev/null 2>&1 || true

healthy() {
    local a_ike b_ike a_child b_child
    a_ike=$(docker exec "$prefix-gw-a" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show vpn ike sa'\"" 2>/dev/null || true)
    b_ike=$(docker exec "$prefix-gw-b" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show vpn ike sa'\"" 2>/dev/null || true)
    a_child=$(docker exec "$prefix-gw-a" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show vpn ipsec sa'\"" 2>/dev/null || true)
    b_child=$(docker exec "$prefix-gw-b" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show vpn ipsec sa'\"" 2>/dev/null || true)

    grep -qE '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]' <<<"$a_ike" \
        && grep -qE '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]' <<<"$b_ike" \
        && grep -qE '^GW-B-tunnel-1[[:space:]]+up[[:space:]]' <<<"$a_child" \
        && grep -qE '^GW-A-tunnel-1[[:space:]]+up[[:space:]]' <<<"$b_child" \
        && docker exec "$prefix-host-a" ping -c 1 -W 1 192.168.2.10 >/dev/null 2>&1 \
        && docker exec "$prefix-host-b" ping -c 1 -W 1 192.168.1.10 >/dev/null 2>&1
}

converged=false
for _attempt in $(seq 1 45); do
    if healthy; then
        converged=true
        break
    fi
    sleep 1
done

if [[ "$converged" != true ]]; then
    echo "ERROR: healthy IPsec state did not converge within the bounded wait" >&2
    exit 1
fi

if ! "$lab_dir/check.sh"; then
    echo "ERROR: IPsec SAs and traffic converged, but the full healthy-state checker failed" >&2
    exit 1
fi

echo "Healthy IPsec end state applied, saved, and verified by the full checker."
