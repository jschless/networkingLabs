#!/usr/bin/env bash
# Arm the opaque live-only missing-optimization fault transactionally.
set -Eeuo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/dmvpn-phase3/break.sh' \
        '' \
        'Require exact health, inject one live-only spoke1 optimization fault, and' \
        'prove reachability and control-plane health survive while directness does not.'
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

prefix=clab-dmvpn-phase3
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
    local saved_after restore_deadline restore_attempt=0 restore_status=1
    local restore_output='' live_config='' live_status=1 remaining attempt_timeout
    local seed_output='' seed_status=0 check_output='' check_status=0
    local restore_complete=false

    # A terminated VyOS config child can hold its lock briefly after its host
    # docker-exec process is gone. Retry only the minimal live leaf under one
    # overall deadline, and require exact live-config evidence before seeding.
    restore_deadline=$((SECONDS + 75))
    while (( SECONDS < restore_deadline )); do
        ((restore_attempt += 1))
        remaining=$((restore_deadline - SECONDS))
        attempt_timeout=20
        (( attempt_timeout > remaining )) && attempt_timeout=$remaining
        restore_output=$(timeout "$attempt_timeout" docker exec "$spoke" su - admin -c \
            '/bin/vbash /opt/dmvpn-phase3/restore-shortcut.sh' 2>&1)
        restore_status=$?
        if (( restore_status == 0 )); then
            live_config=$(timeout 10 docker exec "$spoke" bash -lc \
                "su - admin -c \"/bin/vbash -ic 'show configuration commands'\"" \
                2>/dev/null)
            live_status=$?
            if (( live_status == 0 )) \
                && grep -qx 'set protocols nhrp tunnel tun0 shortcut' \
                    <<<"$live_config"; then
                restore_complete=true
                break
            fi
        fi
        (( SECONDS < restore_deadline )) && sleep 2
    done

    if [[ "$restore_complete" != true ]]; then
        echo "ERROR: rollback restore step did not recover the exact live shortcut leaf after $restore_attempt attempt(s); last restore status $restore_status, live-query status $live_status" >&2
        [[ -z "$restore_output" ]] || \
            echo "Last restore output: ${restore_output:0:500}" >&2
        return 1
    fi

    saved_after=$(timeout 10 docker exec "$spoke" sha256sum /config/config.boot \
        2>/dev/null | awk '{print $1}')
    if [[ -z "$saved_after" ]]; then
        echo "ERROR: rollback saved-state step could not read /config/config.boot SHA" >&2
        return 1
    fi
    if [[ "$saved_after" != "$saved_before" ]]; then
        echo "ERROR: rollback saved-state step changed /config/config.boot SHA" >&2
        return 1
    fi

    seed_output=$(timeout 90 "$lab_dir/seed-shortcuts.sh" 2>&1) || seed_status=$?
    if (( seed_status != 0 )); then
        echo "ERROR: rollback reseed step failed with status $seed_status" >&2
        [[ -z "$seed_output" ]] || echo "${seed_output:0:500}" >&2
        return 1
    fi

    check_output=$(timeout 150 "$lab_dir/check.sh" 2>&1) || check_status=$?
    if (( check_status != 0 )); then
        echo "ERROR: rollback full-check step failed with status $check_status" >&2
        printf '%s\n' "$check_output" | tail -n 12 >&2
        return 1
    fi

    echo "Rollback restored direct-path optimization, preserved saved state, and passed the complete checker." >&2
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
        echo "ERROR: dmvpn-phase3 is not fully deployed" >&2
        exit 1
    }
done

if ! run_interruptible "$lab_dir/check.sh"; then
    echo "ERROR: the complete healthy build must pass check.sh before arming" >&2
    exit 1
fi

saved_before=$(docker exec "$spoke" sha256sum /config/config.boot | awk '{print $1}')
rollback_armed=true
run_interruptible docker exec "$spoke" su - admin -c \
    '/bin/vbash /opt/dmvpn-phase3/inject-fault.sh' >/dev/null
run_interruptible timeout 10 docker exec "$spoke" vtysh \
    -c 'clear ip nhrp shortcut' -c 'clear ip nhrp cache' >/dev/null

fault_ready=false
for _attempt in $(seq 1 30); do
    hub_nhrp=$(docker exec "$prefix-hub" vtysh -c 'show ip nhrp' 2>/dev/null || true)
    hub_ospf=$(docker exec "$prefix-hub" vtysh -c 'show ip ospf neighbor' 2>/dev/null || true)
    live_config=$(docker exec "$spoke" bash -lc \
        "su - admin -c \"/bin/vbash -ic 'show configuration commands'\"" 2>/dev/null || true)
    saved_config=$(docker exec "$spoke" \
        /usr/bin/vyos-config-to-commands /config/config.boot 2>/dev/null || true)
    spoke_nhrp=$(docker exec "$spoke" vtysh -c 'show ip nhrp' 2>/dev/null || true)
    spoke_shortcuts=$(docker exec "$spoke" vtysh \
        -c 'show ip nhrp shortcut' 2>/dev/null || true)
    saved_after=$(docker exec "$spoke" sha256sum /config/config.boot | awk '{print $1}')

    # Generate target traffic only after collecting the pre-attempt state. With
    # the optimization consumer missing, it must remain reachable via the hub.
    target_ok=false
    timeout 5 docker exec "$spoke" ping -I 192.168.1.1 -c 2 -W 1 \
        192.168.2.1 >/dev/null 2>&1 && target_ok=true
    target_fib=$(docker exec "$spoke" ip -4 route get 192.168.2.1 \
        from 192.168.1.1 2>/dev/null || true)

    # `Via` is a column header; a data row contains prefix then overlay.
    if [[ "$(grep -Ec '^tun0[[:space:]]+dynamic[[:space:]]+172\.16\.0\.1[123][[:space:]]' <<<"$hub_nhrp" || true)" == 3 ]] \
        && [[ "$(grep -Ec '^[0-9]+\..*Full/' <<<"$hub_ospf" || true)" == 3 ]] \
        && ! grep -qE '^set protocols nhrp tunnel tun0 shortcut$' <<<"$live_config" \
        && grep -qE '^set protocols nhrp tunnel tun0 shortcut$' <<<"$saved_config" \
        && ! grep -qE '^tun0[[:space:]]+dynamic[[:space:]]+192\.168\.2\.1[[:space:]]' <<<"$spoke_nhrp" \
        && ! grep -qE '^[[:space:]]*dynamic[[:space:]]+192\.168\.2\.0/24[[:space:]]' <<<"$spoke_shortcuts" \
        && [[ "$target_ok" == true ]] \
        && grep -qE '^192\.168\.2\.1 from 192\.168\.1\.1 via 172\.16\.0\.1 dev tun0([[:space:]]|$)' \
            <<<"$target_fib" \
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
    echo "ERROR: exact healthy checker accepted the missing direct optimization" >&2
    exit 1
fi

rollback_armed=false
trap - ERR EXIT INT TERM
echo "Scenario armed: spoke1-to-spoke2 remains reachable but follows the hub, while registrations, all OSPF adjacencies, saved state, and an unrelated spoke path remain healthy."
echo "The fault is live-only; preserve the evidence before diagnosing it."
