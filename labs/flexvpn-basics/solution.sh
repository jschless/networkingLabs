#!/usr/bin/env bash
# Replace the complete learned state, converge it, and require exact health.
set -euo pipefail

usage() {
    printf '%s\n' 'Usage: labs/flexvpn-basics/solution.sh' '' \
        'Replace the hub and both spoke VTI/IKEv2 states with the healthy answer,' \
        'then wait for the complete checker. Re-running is safe.'
}
case ${1:-} in -h|--help) usage; exit 0 ;; '') ;; *) usage >&2; exit 2 ;; esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-flexvpn-basics
lab_dir=$(cd "$(dirname "$0")" && pwd)
for node in gw-a gw-b gw-c host-a host-b host-c internet; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: flexvpn-basics is not fully deployed" >&2
        exit 1
    }
done

# Load both passive hub definitions before either spoke initiates.
docker exec "$prefix-gw-a" bash /opt/flexvpn-basics/apply-solution.sh
docker exec "$prefix-gw-b" bash /opt/flexvpn-basics/apply-solution.sh
docker exec "$prefix-gw-c" bash /opt/flexvpn-basics/apply-solution.sh

healthy=false
for _attempt in $(seq 1 45); do
    hub_status=$(docker exec "$prefix-gw-a" ipsec status 2>/dev/null || true)
    b_status=$(docker exec "$prefix-gw-b" ipsec status 2>/dev/null || true)
    c_status=$(docker exec "$prefix-gw-c" ipsec status 2>/dev/null || true)
    if [[ "$(grep -c 'ESTABLISHED' <<<"$hub_status" || true)" == 2 ]] \
        && [[ "$(grep -c 'ESTABLISHED' <<<"$b_status" || true)" == 1 ]] \
        && [[ "$(grep -c 'ESTABLISHED' <<<"$c_status" || true)" == 1 ]] \
        && docker exec "$prefix-host-a" ping -c 1 -W 1 192.168.2.10 >/dev/null 2>&1 \
        && docker exec "$prefix-host-a" ping -c 1 -W 1 192.168.3.10 >/dev/null 2>&1 \
        && docker exec "$prefix-host-b" ping -c 1 -W 1 192.168.3.10 >/dev/null 2>&1; then
        healthy=true
        break
    fi
    sleep 1
done
[[ "$healthy" == true ]] || { echo "ERROR: exact route-based IKEv2 state did not converge" >&2; exit 1; }

"$lab_dir/check.sh" || {
    echo "ERROR: basic forwarding converged, but exact healthy-state grading failed" >&2
    exit 1
}
echo "Healthy strongSwan IKEv2/VTI state applied and verified by the full checker."
