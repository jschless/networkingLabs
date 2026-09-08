#!/usr/bin/env bash
# Re-arm the one-leaf live incident transactionally; never save configuration.
set -Eeuo pipefail

usage() {
    printf '%s\n' \
        'Usage: labs/debug-dmvpn-phase1/break.sh' '' \
        'Require exact health, arm the one-leaf live incident, prove its exact' \
        'boundary, preserve saved startup, and roll back on any failed arm.'
}
case ${1:-} in -h|--help) usage; exit 0 ;; '') ;; *) usage >&2; exit 2 ;; esac
(( $# == 0 )) || { usage >&2; exit 2; }

LAB_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=state-lib.sh
source "$LAB_DIR/state-lib.sh"

rollback_armed=false
saved_before=

saved_hashes() {
    local node
    for node in hub spoke1 spoke2 spoke3; do
        printf '%s %s\n' "$node" \
            "$(debug_dmvpn_node "$node" \
                "sha256sum /config/config.boot | cut -d ' ' -f 1")"
    done
}

set_map() {
    docker exec "$(debug_dmvpn_container spoke1)" su - admin -c \
        "/bin/vbash /opt/debug-dmvpn-phase1/set-map.sh $1" >/dev/null
}

rollback_fault() {
    local converged=false
    set_map 10.0.0.1 || return 1
    for _attempt in $(seq 1 50); do
        if debug_dmvpn_verify_state healthy >/dev/null 2>&1; then
            converged=true
            break
        fi
        sleep 1
    done
    [[ "$converged" == true ]] || return 1
    [[ "$(saved_hashes)" == "$saved_before" ]] || return 1
    "$LAB_DIR/check.sh" >/dev/null
}

rollback_and_exit() {
    local reason=$1 requested_status=$2 rollback_status=0
    trap - ERR EXIT INT TERM
    set +e
    if [[ "$rollback_armed" == true ]]; then
        rollback_fault || rollback_status=$?
        if (( rollback_status == 0 )); then
            echo "Transactional rollback restored exact health after $reason." >&2
        else
            echo "ERROR: transactional rollback failed after $reason" >&2
        fi
    fi
    (( requested_status == 0 )) && requested_status=1
    exit "$requested_status"
}

on_exit() {
    local status=$1
    (( status == 0 )) || rollback_and_exit EXIT "$status"
}

trap 'rollback_and_exit ERR "$?"' ERR
trap 'on_exit "$?"' EXIT
trap 'rollback_and_exit INT 130' INT
trap 'rollback_and_exit TERM 143' TERM

if ! "$LAB_DIR/check.sh" >/dev/null; then
    echo 'ERROR: exact health is required before re-arming the incident' >&2
    exit 1
fi

saved_before=$(saved_hashes)
rollback_armed=true
set_map 10.0.0.254
# Re-arming from a converged lab otherwise preserves the existing Full
# adjacency even though new unicast exchange is broken. Reset only spoke1's
# ephemeral OSPF process so the exact fresh-incident ExStart boundary is
# reproduced; timeout/failure enters the transactional ERR rollback.
timeout 10 docker exec "$(debug_dmvpn_container spoke1)" \
    /usr/bin/vtysh -c 'clear ip ospf process' >/dev/null

# A validator may set this only to exercise rollback after the real mutation.
case ${DEBUG_DMVPN_BREAK_TEST_AFTER_MUTATION:-} in
    '') ;;
    ERR) false ;;
    PAUSE)
        marker=${DEBUG_DMVPN_BREAK_TEST_MARKER:-/tmp/debug-dmvpn-phase1-break.mutated}
        printf 'mutated\n' >"$marker"
        while :; do sleep 1; done
        ;;
    *) echo 'ERROR: invalid test-only break hook' >&2; exit 2 ;;
esac

fault_ready=false
for _attempt in $(seq 1 50); do
    if debug_dmvpn_verify_state incident >/dev/null 2>&1; then
        fault_ready=true
        break
    fi
    sleep 1
done
[[ "$fault_ready" == true ]] || {
    echo 'ERROR: incident did not reach every exact bounded postcondition' >&2
    exit 1
}
[[ "$(saved_hashes)" == "$saved_before" ]] || {
    echo 'ERROR: saved startup state changed while arming the incident' >&2
    exit 1
}

rollback_armed=false
trap - ERR EXIT INT TERM
echo 'Incident re-armed: preserve route, NHRP, adjacency, traffic, and packet evidence before repair.'
