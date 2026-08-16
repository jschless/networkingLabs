#!/usr/bin/env bash
# Restore only the live Task 5 ESP-hash fault. Re-running is safe.
set -euo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/gre-ipsec/repair.sh' \
        '' \
        'Restore the live ESP proposal hash, reset the child SA, and require' \
        'the complete healthy checker without changing saved configuration.'
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-gre-ipsec
lab_dir=$(cd "$(dirname "$0")" && pwd)
gateway="$prefix-gw-a"
peer="$prefix-gw-b"

for device in "$gateway" "$peer" "$prefix-host-a" "$prefix-host-b" "$prefix-internet"; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$device" 2>/dev/null)" == true ]] || {
        echo "ERROR: gre-ipsec is not fully deployed" >&2
        exit 1
    }
done

saved_a_before=$(docker exec "$gateway" sha256sum /config/config.boot | awk '{print $1}')
saved_b_before=$(docker exec "$peer" sha256sum /config/config.boot | awk '{print $1}')

docker exec "$peer" su - admin -c \
    '/bin/vbash /opt/gre-ipsec/restore-hash.sh' >/dev/null
docker exec "$gateway" bash -lc \
    "su - admin -c \"/bin/vbash -ic 'reset vpn ipsec site-to-site peer GW-B tunnel 1'\"" \
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
    saved_a_after=$(docker exec "$gateway" sha256sum /config/config.boot | awk '{print $1}')
    saved_b_after=$(docker exec "$peer" sha256sum /config/config.boot | awk '{print $1}')
    if [[ "$(grep -Ec '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]' <<<"$a_ike" || true)" == 1 ]] \
        && [[ "$(grep -Ec '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]' <<<"$b_ike" || true)" == 1 ]] \
        && [[ "$(grep -Ec '^GW-B-tunnel-1[[:space:]]+up[[:space:]]' <<<"$a_child" || true)" == 1 ]] \
        && [[ "$(grep -Ec '^GW-A-tunnel-1[[:space:]]+up[[:space:]]' <<<"$b_child" || true)" == 1 ]] \
        && docker exec "$prefix-host-a" ping -c 1 -W 1 192.168.2.10 >/dev/null 2>&1 \
        && docker exec "$prefix-host-b" ping -c 1 -W 1 192.168.1.10 >/dev/null 2>&1 \
        && [[ "$saved_a_after" == "$saved_a_before" ]] \
        && [[ "$saved_b_after" == "$saved_b_before" ]]; then
        converged=true
        break
    fi
    sleep 1
done

if [[ "$converged" != true ]]; then
    echo "ERROR: repair did not restore service and both saved checksums within the bounded wait" >&2
    exit 1
fi

if ! "$lab_dir/check.sh"; then
    echo "ERROR: minimal repair restored service, but exact healthy state failed; run solution.sh to replace polluted learned state" >&2
    exit 1
fi

echo "Repair converged with unchanged saved checksums and a full checker pass."
