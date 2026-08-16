#!/usr/bin/env bash
# Restore only the live Task 5 IKE-hash fault. Re-running is safe.
set -euo pipefail

prefix=clab-ipsec-basics
lab_dir=$(cd "$(dirname "$0")" && pwd)
gateway="$prefix-gw-a"
peer="$prefix-gw-b"

for device in "$gateway" "$peer" "$prefix-host-a" "$prefix-host-b"; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$device" 2>/dev/null)" == true ]] || {
        echo "ERROR: ipsec-basics is not fully deployed" >&2
        exit 1
    }
done

saved_before=$(docker exec "$peer" sha256sum /config/config.boot | awk '{print $1}')

docker exec "$peer" su - admin -c \
    '/bin/vbash /opt/ipsec-basics/restore-hash.sh' >/dev/null
docker exec "$gateway" bash -lc \
    "su - admin -c \"/bin/vbash -ic 'reset vpn ipsec site-to-site peer GW-B'\"" \
    >/dev/null 2>&1 || true

converged=false
for _attempt in $(seq 1 45); do
    a_ike=$(docker exec "$gateway" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show vpn ike sa'\"" 2>/dev/null || true)
    b_ike=$(docker exec "$peer" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show vpn ike sa'\"" 2>/dev/null || true)
    a_child=$(docker exec "$gateway" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show vpn ipsec sa'\"" 2>/dev/null || true)
    b_child=$(docker exec "$peer" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show vpn ipsec sa'\"" 2>/dev/null || true)
    saved_after=$(docker exec "$peer" sha256sum /config/config.boot | awk '{print $1}')
    if grep -qE '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]' <<<"$a_ike" \
        && grep -qE '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]' <<<"$b_ike" \
        && grep -qE '^GW-B-tunnel-1[[:space:]]+up[[:space:]]' <<<"$a_child" \
        && grep -qE '^GW-A-tunnel-1[[:space:]]+up[[:space:]]' <<<"$b_child" \
        && docker exec "$prefix-host-a" ping -c 1 -W 1 192.168.2.10 >/dev/null 2>&1 \
        && docker exec "$prefix-host-b" ping -c 1 -W 1 192.168.1.10 >/dev/null 2>&1 \
        && [[ "$saved_after" == "$saved_before" ]]; then
        converged=true
        break
    fi
    sleep 1
done

if [[ "$converged" != true ]]; then
    echo "ERROR: repair did not restore local service and the saved checksum within the bounded wait" >&2
    exit 1
fi

if ! "$lab_dir/check.sh"; then
    echo "ERROR: repair restored basic service, but the complete live/saved healthy-state checker failed; run solution.sh to replace polluted learned state" >&2
    exit 1
fi

echo "Repair converged with an unchanged saved checksum and a full checker pass."
