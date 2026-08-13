#!/usr/bin/env bash
# Arm the opaque Task 5 multicast-replication fault transactionally.
set -Eeuo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/dmvpn-phase1/break.sh' \
        '' \
        'Require exact health, inject one live-only fault, and prove that NHRP' \
        'and underlay survive while only spoke1 OSPF/service reachability fails.'
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
rollback_armed=false
saved_before=

restore_fault() {
    local _attempt saved_after hub_ospf converged=false
    docker exec "$spoke" su - admin -c \
        '/bin/vbash /opt/dmvpn-phase1/restore-multicast.sh' >/dev/null || return 1
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
    [[ "$converged" == true ]] || return 1
    "$lab_dir/check.sh" >/dev/null
    echo "Rollback restored multicast replication, unchanged saved state, and full service." >&2
}

rollback_and_exit() {
    local reason=$1 requested_status=$2 rollback_status=0
    trap - ERR EXIT INT TERM
    set +e
    if [[ "$rollback_armed" == true ]]; then
        restore_fault || rollback_status=$?
        if (( rollback_status != 0 )); then
            echo "ERROR: transactional rollback failed after $reason" >&2
        else
            echo "Transactional rollback completed after $reason" >&2
        fi
    fi
    (( requested_status == 0 )) && requested_status=1
    exit "$requested_status"
}

on_exit() {
    local status=$1
    if (( status != 0 )); then
        rollback_and_exit EXIT "$status"
    fi
}

trap 'rollback_and_exit ERR "$?"' ERR
trap 'on_exit "$?"' EXIT
trap 'rollback_and_exit INT 130' INT
trap 'rollback_and_exit TERM 143' TERM

for node in hub spoke1 spoke2 spoke3 br-wan; do
    [[ "$(docker inspect --format '{{.State.Running}}' "$prefix-$node" 2>/dev/null)" == true ]] || {
        echo "ERROR: dmvpn-phase1 is not fully deployed" >&2
        exit 1
    }
done

live_config=$(docker exec "$spoke" bash -lc \
    "su - admin -c \"/bin/vbash -ic 'show configuration commands'\"" 2>/dev/null || true)
if ! grep -qE "^set protocols nhrp tunnel tun0 multicast ['\"]?10\.0\.0\.1['\"]?$" \
    <<<"$live_config" \
    || grep -qE "^set protocols nhrp tunnel tun0 multicast ['\"]?10\.0\.0\.254['\"]?$" \
        <<<"$live_config"; then
    echo "ERROR: the fault already exists or spoke1 lacks the exact healthy multicast target" >&2
    exit 1
fi

if ! "$lab_dir/check.sh"; then
    echo "ERROR: complete live and saved healthy state must pass check.sh before arming" >&2
    exit 1
fi

saved_before=$(docker exec "$spoke" sha256sum /config/config.boot | awk '{print $1}')
rollback_armed=true
docker exec "$spoke" su - admin -c \
    '/bin/vbash /opt/dmvpn-phase1/inject-fault.sh' >/dev/null

fault_ready=false
for _attempt in $(seq 1 65); do
    hub_nhrp=$(docker exec "$prefix-hub" vtysh -c 'show ip nhrp' 2>/dev/null || true)
    hub_ospf=$(docker exec "$prefix-hub" vtysh -c 'show ip ospf neighbor' 2>/dev/null || true)
    spoke_ospf=$(docker exec "$spoke" vtysh -c 'show ip ospf neighbor' 2>/dev/null || true)
    spoke_routes=$(docker exec "$spoke" vtysh -c 'show ip route ospf' 2>/dev/null || true)
    live_config=$(docker exec "$spoke" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show configuration commands'\"" 2>/dev/null || true)
    saved_after=$(docker exec "$spoke" sha256sum /config/config.boot | awk '{print $1}')

    if grep -qE '^tun0[[:space:]]+dynamic[[:space:]]+172\.16\.0\.11[[:space:]]+10\.0\.0\.11' \
            <<<"$hub_nhrp" \
        && [[ "$(grep -Ec '^[0-9]+\..*Full/' <<<"$hub_ospf" || true)" == 2 ]] \
        && ! grep -qE '^10\.0\.0\.11[[:space:]].*Full/' <<<"$hub_ospf" \
        && grep -qE '^10\.0\.0\.1[[:space:]].*Init/' <<<"$spoke_ospf" \
        && ! grep -qE '^O[^[:space:]]*[[:space:]]+192\.168\.[23]\.0/24' <<<"$spoke_routes" \
        && docker exec "$spoke" ping -I 10.0.0.11 -c 1 -W 1 \
            10.0.0.1 >/dev/null 2>&1 \
        && docker exec "$spoke" ping -I 172.16.0.11 -c 1 -W 1 \
            172.16.0.1 >/dev/null 2>&1 \
        && ! docker exec "$spoke" ping -I 192.168.1.1 -c 1 -W 1 \
            192.168.2.1 >/dev/null 2>&1 \
        && docker exec "$prefix-spoke2" ping -I 192.168.2.1 -c 1 -W 1 \
            192.168.3.1 >/dev/null 2>&1 \
        && grep -qE "^set protocols nhrp tunnel tun0 multicast ['\"]?10\.0\.0\.254['\"]?$" \
            <<<"$live_config" \
        && [[ "$saved_after" == "$saved_before" ]]; then
        fault_ready=true
        break
    fi
    sleep 1
done

if [[ "$fault_ready" != true ]]; then
    echo "ERROR: scenario did not reach every bounded causal postcondition" >&2
    exit 1
fi

rollback_armed=false
trap - ERR EXIT INT TERM
echo "Scenario armed: WAN and NHRP are healthy, spoke1 sees the hub only in Init, remote routes are absent, and spokes2/3 remain healthy."
echo "The fault is live-only; preserve the evidence before diagnosing it."
