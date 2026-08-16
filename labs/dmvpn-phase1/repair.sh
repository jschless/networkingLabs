#!/usr/bin/env bash
# Restore only the live Task 5 multicast-target fault. Re-running is safe.
set -euo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/dmvpn-phase1/repair.sh' \
        '' \
        'Restore spoke1 multicast replication, preserve saved configuration,' \
        'wait for OSPF recovery, and require the complete healthy checker.'
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase1
lab_dir=$(cd "$(dirname "$0")" && pwd)
spoke="$prefix-spoke1"

for node in hub spoke1 spoke2 spoke3 br-wan; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: dmvpn-phase1 is not fully deployed" >&2
        exit 1
    }
done

saved_before=$(docker exec "$spoke" sha256sum /config/config.boot | awk '{print $1}')
docker exec "$spoke" su - admin -c \
    '/bin/vbash /opt/dmvpn-phase1/restore-multicast.sh' >/dev/null

converged=false
for _attempt in $(seq 1 50); do
    hub_ospf=$(docker exec "$prefix-hub" vtysh -c 'show ip ospf neighbor' 2>/dev/null || true)
    saved_after=$(docker exec "$spoke" sha256sum /config/config.boot | awk '{print $1}')
    if [[ "$(grep -Ec '^[0-9]+\..*Full/' <<<"$hub_ospf" || true)" == 3 ]] \
        && docker exec "$spoke" ping -I 192.168.1.1 -c 1 -W 1 \
            192.168.2.1 >/dev/null 2>&1 \
        && [[ "$saved_after" == "$saved_before" ]]; then
        converged=true
        break
    fi
    sleep 1
done

if [[ "$converged" != true ]]; then
    echo "ERROR: minimal repair did not restore adjacency, service, and unchanged saved state" >&2
    exit 1
fi

if ! "$lab_dir/check.sh"; then
    echo "ERROR: minimal repair restored service, but exact healthy state failed; run solution.sh for complete replacement" >&2
    exit 1
fi

echo "Repair converged with unchanged saved state and a full checker pass."
