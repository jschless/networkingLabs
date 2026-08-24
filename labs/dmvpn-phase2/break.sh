#!/usr/bin/env bash
# Arm the opaque wrong service-host-map observation fault transactionally.
set -Eeuo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/dmvpn-phase2/break.sh' \
        '' \
        'Require exact health, inject one live-only spoke1 service-host-map fault, and' \
        'prove that registration, BGP, and unrelated spoke paths stay healthy.'
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase2
lab_dir=$(cd "$(dirname "$0")" && pwd)
spoke="$prefix-spoke1"
rollback_armed=false
saved_before=
active_child_pid=

stop_active_child() {
    local child_pid=${active_child_pid:-} _attempt
    [[ -n "$child_pid" ]] || return 0
    if kill -0 "$child_pid" >/dev/null 2>&1; then
        kill -TERM -- "-$child_pid" >/dev/null 2>&1 || true
        for _attempt in $(seq 1 20); do
            kill -0 "$child_pid" >/dev/null 2>&1 || break
            sleep 0.1
        done
        kill -KILL -- "-$child_pid" >/dev/null 2>&1 || true
    fi
    wait "$child_pid" >/dev/null 2>&1 || true
    active_child_pid=
}

run_interruptible() {
    local status=0
    setsid --wait "$@" &
    active_child_pid=$!
    wait "$active_child_pid" || status=$?
    active_child_pid=
    return "$status"
}

restore_fault() {
    local saved_after
    timeout 20 docker exec "$spoke" su - admin -c \
        '/bin/vbash /opt/dmvpn-phase2/restore-service-host-map.sh' >/dev/null || return 1
    timeout 45 "$lab_dir/seed-shortcuts.sh" >/dev/null || return 1
    saved_after=$(docker exec "$spoke" sha256sum /config/config.boot | awk '{print $1}')
    [[ "$saved_after" == "$saved_before" ]] || return 1
    timeout 60 "$lab_dir/check.sh" >/dev/null
    echo "Rollback removed the wrong service-host map, preserved saved state, and restored the complete reference." >&2
}

rollback_and_exit() {
    local reason=$1 requested_status=$2 rollback_status=0
    trap - ERR EXIT
    trap '' INT TERM
    set +e
    stop_active_child
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
        echo "ERROR: dmvpn-phase2 is not fully deployed" >&2
        exit 1
    }
done

if ! run_interruptible "$lab_dir/check.sh"; then
    echo "ERROR: the complete healthy reference must pass check.sh before arming" >&2
    exit 1
fi

saved_before=$(docker exec "$spoke" sha256sum /config/config.boot | awk '{print $1}')
rollback_armed=true
run_interruptible docker exec "$spoke" su - admin -c \
    '/bin/vbash /opt/dmvpn-phase2/inject-fault.sh' >/dev/null

fault_ready=false
for _attempt in $(seq 1 30); do
    hub_nhrp=$(docker exec "$prefix-hub" vtysh -c 'show ip nhrp' 2>/dev/null || true)
    hub_bgp=$(docker exec "$prefix-hub" vtysh -c 'show bgp ipv4 unicast summary' 2>/dev/null || true)
    spoke_nhrp=$(docker exec "$spoke" vtysh -c 'show ip nhrp' 2>/dev/null || true)
    live_config=$(docker exec "$spoke" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show configuration commands'\"" 2>/dev/null || true)
    saved_after=$(docker exec "$spoke" sha256sum /config/config.boot | awk '{print $1}')

    if grep -qE '^tun0[[:space:]]+dynamic[[:space:]]+172\.16\.0\.11[[:space:]]+10\.0\.0\.11' \
            <<<"$hub_nhrp" \
        && [[ "$(grep -Ec '^tun0[[:space:]]+dynamic[[:space:]]+172\.16\.0\.1[123][[:space:]]' <<<"$hub_nhrp" || true)" == 3 ]] \
        && [[ "$(grep -Ec '^172\.16\.0\.1[123][[:space:]]+4[[:space:]]+65000[[:space:]].*[[:space:]][0-9]+([[:space:]]|$)' <<<"$hub_bgp" || true)" == 3 ]] \
        && grep -qE '^tun0[[:space:]]+dynamic[[:space:]]+172\.16\.0\.12[[:space:]]+10\.0\.0\.12[[:space:]]+10\.0\.0\.12([[:space:]]|$)' \
            <<<"$spoke_nhrp" \
        && grep -qE '^tun0[[:space:]]+dynamic[[:space:]]+172\.16\.0\.13[[:space:]]+10\.0\.0\.13[[:space:]]+10\.0\.0\.13([[:space:]]|$)' \
            <<<"$spoke_nhrp" \
        && grep -qE '^tun0[[:space:]]+static[[:space:]]+192\.168\.2\.1[[:space:]]+10\.0\.0\.254([[:space:]]|$)' \
            <<<"$spoke_nhrp" \
        && grep -qE "^set protocols nhrp tunnel tun0 map tunnel-ip ['\"]?192\.168\.2\.1['\"]? nbma ['\"]?10\.0\.0\.254['\"]?$" \
            <<<"$live_config" \
        && ! timeout 5 docker exec "$spoke" ping -I 192.168.1.1 -c 2 -W 1 \
            192.168.2.1 >/dev/null 2>&1 \
        && timeout 5 docker exec "$spoke" ping -I 192.168.1.1 -c 2 -W 1 \
            192.168.3.1 >/dev/null 2>&1 \
        && timeout 5 docker exec "$prefix-spoke2" ping -I 192.168.2.1 -c 2 -W 1 \
            192.168.3.1 >/dev/null 2>&1 \
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

if run_interruptible "$lab_dir/check.sh" >/dev/null 2>&1; then
    echo "ERROR: exact healthy checker accepted the wrong service-host map" >&2
    exit 1
fi

rollback_armed=false
trap - ERR EXIT INT TERM
echo "Scenario armed: spoke1-to-spoke2 fails at resolved service-host forwarding while hub registration, iBGP, spoke1-to-spoke3, and spoke2-to-spoke3 remain healthy."
echo "The fault is live-only; preserve the evidence before diagnosing it."
