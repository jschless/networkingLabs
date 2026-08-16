#!/usr/bin/env bash
# Replace, save, converge, and grade all learned spoke control-plane state.
set -euo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/dmvpn-phase1/solution.sh' \
        '' \
        'Replace every spoke learned subtree with the healthy answer, save it,' \
        'wait for convergence, and require the complete checker.'
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase1
lab_dir=$(cd "$(dirname "$0")" && pwd)

for node in hub spoke1 spoke2 spoke3 br-wan; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: dmvpn-phase1 is not fully deployed" >&2
        exit 1
    }
done

for spoke in spoke1 spoke2 spoke3; do
    docker exec "$prefix-$spoke" su - admin -c \
        '/bin/vbash /opt/dmvpn-phase1/apply-solution.sh' >/dev/null
done

converged=false
for _attempt in $(seq 1 50); do
    hub_nhrp=$(docker exec "$prefix-hub" vtysh -c 'show ip nhrp' 2>/dev/null || true)
    hub_ospf=$(docker exec "$prefix-hub" vtysh -c 'show ip ospf neighbor' 2>/dev/null || true)
    if [[ "$(grep -Ec '^tun0[[:space:]]+dynamic' <<<"$hub_nhrp" || true)" == 3 ]] \
        && [[ "$(grep -Ec '^[0-9]+\..*Full/' <<<"$hub_ospf" || true)" == 3 ]] \
        && docker exec "$prefix-spoke1" ping -I 192.168.1.1 -c 1 -W 1 \
            192.168.2.1 >/dev/null 2>&1; then
        converged=true
        break
    fi
    sleep 1
done

if [[ "$converged" != true ]]; then
    echo "ERROR: healthy NHRP, OSPF, and service state did not converge within the bounded wait" >&2
    exit 1
fi

if ! "$lab_dir/check.sh"; then
    echo "ERROR: basic convergence succeeded, but the full healthy-state checker failed" >&2
    exit 1
fi

echo "Healthy DMVPN Phase 1 state applied, saved, and verified by the full checker."
